import tkinter as tk
import urllib.request, time, threading, socket
from queue import Queue, Empty

# --- Environment URLs ---

ENVIRONMENTS = {
    "Google": "https://www.google.com",                  # healthy
    "Example": "https://example.com",                    # healthy
    "Redirect4": "https://httpbin.org/absolute-redirect/4",  # 4 redirects
    "Redirect5": "https://httpbin.org/absolute-redirect/5",  # 5 redirects
    "TempRedirect": "https://httpbin.org/status/307",   # 307
    "Slow1": "https://httpbin.org/delay/2",             # slow 2s
    "Slow2": "https://httpbin.org/delay/3",             # slow 3s
    "ServerError1": "https://httpbin.org/status/500",   # 500
    "ServerError2": "https://httpbin.org/status/502",   # 502
    "NotFound": "https://httpbin.org/status/404",       # 404
    "GitHub": "https://github.com",                     # healthy
    "HTTPBin200": "https://httpbin.org/status/200",     # healthy
    "HTTPBin301": "https://httpbin.org/status/301",     # redirect
    "HTTPBin308": "https://httpbin.org/status/308",     # redirect
    "SlowRedirect": "https://httpbin.org/redirect/3",   # 3 redirects
    "StackOverflow": "https://stackoverflow.com",       # healthy
    "InvalidSite": "https://httpbin.org/status/503",    # down
    "Delay5": "https://httpbin.org/delay/5",           # slow 5s
    "Redirect2": "https://httpbin.org/redirect/2",      # 2 redirects
    "FakeDown": "https://nonexistent.example.com",      # fails
}

# =============================================================================
# PERFORMANCE CONFIGURATION
# =============================================================================

# --- Network & Monitoring ---
CHECK_INTERVAL = 30        # Seconds between full monitoring cycles
REQUEST_TIMEOUT = 2.5      # HTTP response timeout (s); 1.5–3s recommended

# --- Threading Control ---
MAX_THREADS = 5            # Max simultaneous site checks; ~1 thread per 10-15 sites

# --- UI Performance ---
UPDATE_INTERVAL = 200      # UI refresh interval (ms); 150–500ms recommended

# --- Smart Retry Logic (Adaptive Checking) ---
BACKOFF_FACTOR = 1.5       # Retry multiplier; 1.5=gentle, 2.0=aggressive (30→45→67→100s)
MAX_BACKOFF = 300          # Max retry delay (s); 300=5min; set=CHECK_INTERVAL to disable

# --- UI Optimization ---
CHANGE_DETECTION_ONLY = True  # Only redraw on status change; faster, debug=False

# --- Color Palette ---
ROOT_BG_COLOR = "#123456"  # Background
ROOT_FG_COLOR = "#F7F7FF"  # Foreground
RESPONSE_FAST = "#009E73"
RESPONSE_MODERATE = "#F0E442"
RESPONSE_SLOW = "#2196F3"
RESPONSE_FAIL = "#F44336"
RESPONSE_ERROR = "#FF7043"

# =============================================================================
# DATA STRUCTURES & STATE MANAGEMENT
# =============================================================================

labels = {}                 # UI label widgets: {env_name: tkinter.Label}
updates = Queue(maxsize=20) # Status change queue; limited size prevents memory bloat
cache = {}                  # Last known status: {env_name: (status_text, color)} for change detection

failure_counts = {}         # Consecutive failure tracker: {env_name: failure_count} for adaptive backoff
last_check_times = {}       # Per-site last check timestamps: {env_name: unix_timestamp} for adaptive checking

active_threads = 0          # Simple thread counter; lightweight alternative to thread pools
ui_update_pending = False   # Debounce flag to prevent UI update spam; reserved for future use


# =============================================================================
# HTTP CONNECTION MANAGEMENT
# =============================================================================

class ConnectionManager:
    """Optimized HTTP connection handler with redirect and SSL support"""
    
    def __init__(self):
        # Create opener with redirect and HTTPS handlers
        redirect_handler = urllib.request.HTTPRedirectHandler()  # Handle 30x redirects
        https_handler = urllib.request.HTTPSHandler(context=None)  # SSL/TLS support
        self.opener = urllib.request.build_opener(redirect_handler, https_handler)
        
        # Set global socket timeout for all connections
        socket.setdefaulttimeout(REQUEST_TIMEOUT)
        
    def check_url(self, url):
        """Create optimized HTTP request with proper headers"""
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'Mozilla/5.0 (Monitor)')  # Standard UA to avoid blocks
        req.add_header('Accept', '*/*')                        # Accept any content type
        req.add_header('Connection', 'close')                  # Don't keep connections alive
        return self.opener.open(req, timeout=REQUEST_TIMEOUT)

conn_mgr = ConnectionManager()

# =============================================================================
# CORE MONITORING LOGIC
# =============================================================================

def check_site(name, url):
    """
    Perform HTTP check for a single site and return status information
    
    Returns: (site_name, status_text, color_code) or None on error
    Status codes: "XXXms" for response time, "DOWN" for failures, "HTTP_CODE" for errors
    """
    start = time.time()
    try:
        with conn_mgr.check_url(url) as r:
            response_time_ms = int((time.time() - start) * 1000)
            http_status_code = r.getcode()
            
            # Reset failure count on any successful connection
            failure_counts[name] = 0
            
            # Accept 2xx (success) and 3xx (redirect) as healthy responses
            if 200 <= http_status_code < 400:
                # Color based on response time performance
                if response_time_ms < 500:
                    color = RESPONSE_FAST  # excellent
                elif response_time_ms < 2000:
                    color = RESPONSE_MODERATE  # acceptable
                else:
                    color = RESPONSE_SLOW  # slow
                    
                return name, f"{response_time_ms}ms", color
            else:
                # 4xx/5xx errors - show HTTP status code
                return name, f"{http_status_code}", RESPONSE_FAIL
                
    except urllib.error.HTTPError as e:
        # HTTP protocol errors (404, 500, etc.)
        failure_counts[name] = failure_counts.get(name, 0) + 1
        return name, f"{e.code}", RESPONSE_FAIL
    except Exception as e:
        # Network errors, timeouts, DNS failures, etc.
        failure_counts[name] = failure_counts.get(name, 0) + 1
        return name, "DOWN", RESPONSE_ERROR

# =============================================================================
# ADAPTIVE MONITORING SYSTEM
# =============================================================================

def should_check_site(name):
    """
    Determine if a site needs checking based on adaptive intervals
    
    Logic:
    - Healthy sites: checked every CHECK_INTERVAL seconds
    - Failed sites: checked less frequently using exponential backoff
    - Prevents wasting resources on persistently down sites
    - Still monitors failed sites in case they recover
    """
    now = time.time()
    last_check = last_check_times.get(name, 0)
    consecutive_failures = failure_counts.get(name, 0)
    
    # Calculate adaptive interval based on failure history
    if consecutive_failures == 0:
        # Healthy site - use standard interval
        required_interval = CHECK_INTERVAL
    else:
        # Failed site - exponential backoff
        # Example: 30s → 45s → 67s → 100s → 150s → 225s → 300s (max)
        backoff_interval = CHECK_INTERVAL * (BACKOFF_FACTOR ** consecutive_failures)
        required_interval = min(backoff_interval, MAX_BACKOFF)
    
    # Check if enough time has passed since last check
    return (now - last_check) >= required_interval

def check_site_threaded(name, url):
    """
    Thread worker function for individual site checking
    
    Features:
    - Thread-safe counter management
    - Change detection to reduce UI updates
    - Non-blocking queue operations
    - Graceful error handling
    """
    global active_threads
    active_threads += 1  # Atomic increment (thread-safe for simple int)
    
    try:
        result = check_site(name, url)
        if result:
            # Change detection: only update UI if status actually changed
            old_status = cache.get(name, (None, None))
            new_status = result[1:]  # (status_text, color)
            
            if CHANGE_DETECTION_ONLY and old_status == new_status:
                return  # Status unchanged - skip expensive UI update
                
            # Update cache and queue UI update
            cache[name] = new_status
            try:
                updates.put(result, block=False)  # Non-blocking to prevent thread hangs
            except:
                pass  # Queue full - drop this update (UI will catch up later)
                
    except Exception:
        pass  # Silent failure to reduce log spam and overhead
    finally:
        active_threads -= 1  # Always decrement, even on errors

def check_sites_batch():
    """
    Main monitoring batch function with adaptive checking
    
    Features:
    - Only checks sites that need checking (adaptive intervals)
    - Thread limiting to control resource usage
    - Timestamp tracking for individual site intervals
    """
    global active_threads
    current_time = time.time()
    sites_to_check = []
    
    # Filter sites that actually need checking (adaptive intervals)
    for name, url in ENVIRONMENTS.items():
        if should_check_site(name):
            sites_to_check.append((name, url))
            last_check_times[name] = current_time  # Record check time
    
    # Start threads only for sites that need checking
    for name, url in sites_to_check:
        # Thread limiting: wait if at capacity
        while active_threads >= MAX_THREADS:
            time.sleep(0.01)  # Very short wait to prevent busy-waiting
        
        # Create daemon thread (auto-cleanup when main program exits)
        thread = threading.Thread(target=check_site_threaded, args=(name, url), daemon=True, name="SiteMoniter")
        thread.start()

# =============================================================================
# UI UPDATE SYSTEM
# =============================================================================

def process_updates():
    """
    Efficient UI update processor with batching
    
    Features:
    - Processes multiple updates per cycle (reduces function call overhead)
    - Batches UI changes and applies them together (reduces redraws)
    - Self-scheduling for continuous operation
    - Bounded processing to prevent UI freezing
    """
    global ui_update_pending
    ui_update_pending = False
    
    updates_processed = 0
    batch_updates = []
    
    # Collect multiple updates in one cycle (batch processing)
    while updates_processed < 10:  # Process up to 10 updates per cycle
        try:
            update_data = updates.get(block=False)  # Non-blocking queue read
            batch_updates.append(update_data)
            updates_processed += 1
        except Empty:
            break  # No more updates available
    
    # Apply all collected updates in a single batch
    if batch_updates:
        for name, status_text, color in batch_updates:
            if name in labels:  # Safety check for UI cleanup
                # Update label with combined name:status format
                labels[name].config(text=f"{name}: {status_text}", fg=color)
        
        # Single UI refresh after all updates (much more efficient than per-update)
        root.update_idletasks()
    
    # Schedule next update cycle
    root.after(UPDATE_INTERVAL, process_updates)

# =============================================================================
# BACKGROUND MONITORING THREAD
# =============================================================================

def monitor_loop():
    """
    Main monitoring loop running in background thread
    
    Features:
    - Continuous monitoring with adaptive intervals
    - Memory cleanup to prevent leaks
    - Runs as daemon thread (auto-cleanup on exit)
    """
    while True:
        # Perform batch site checking
        check_sites_batch()
        
        # Periodic memory cleanup to prevent bloat
        if len(cache) > len(ENVIRONMENTS) * 2:
            # Clear caches if they grow too large
            # Keeps only essential data, allows fresh start
            cache.clear()
            failure_counts.clear()
        
        # Sleep until next monitoring cycle
        time.sleep(CHECK_INTERVAL)

# --- Lightweight UI setup ---
root = tk.Tk()
root.overrideredirect(True)
root.attributes("-topmost", True)
root.configure(bg=ROOT_BG_COLOR)
root.attributes("-transparentcolor", ROOT_BG_COLOR)

# Optimize window for less redraws
root.resizable(False, False)

# --- Efficient drag support ---
drag_data = {"x": 0, "y": 0}

def start_drag(e):
    drag_data["x"], drag_data["y"] = e.x, e.y

def drag(e):
    x = root.winfo_pointerx() - drag_data["x"]
    y = root.winfo_pointery() - drag_data["y"]
    root.geometry(f"+{x}+{y}")

# --- Minimal close button ---
close_btn = tk.Label(root, text=">", fg=ROOT_FG_COLOR, bg=ROOT_BG_COLOR,
                     font=("Consolas", 6, "bold"), width=2)
close_btn.grid(row=0, column=0, columnspan=4, sticky="nw", padx=2, pady=1)
close_btn.bind("<Button-1>", lambda e: root.destroy())
close_btn.bind("<Button-3>", start_drag)
close_btn.bind("<B3-Motion>", drag)
close_btn.bind("<Enter>", lambda e: close_btn.config(text="x", bg=RESPONSE_FAIL))
close_btn.bind("<Leave>", lambda e: close_btn.config(text=">", bg=ROOT_BG_COLOR))

# --- Optimized layout creation (unchanged but more efficient) ---
env_list = list(ENVIRONMENTS.keys())
rows_per_col = (len(env_list) + 1) // 2

# Pre-calculate layout to avoid repeated computations
label_configs = []

# Column 1
for i in range(rows_per_col):
    if i < len(env_list):
        name = env_list[i]
        label_configs.append((name, i + 1, 0))

# Column 2  
for i in range(rows_per_col):
    env_idx = rows_per_col + i
    if env_idx < len(env_list):
        name = env_list[env_idx]
        label_configs.append((name, i + 1, 2))

# Create all labels in one pass
for name, row, col in label_configs:
    lbl = tk.Label(root, text=f"{name}: ...", fg=ROOT_FG_COLOR, bg=ROOT_BG_COLOR,
                   font=("Consolas", 8), anchor="w", width=20) # Increase width to extend col width
    lbl.grid(row=row, column=col, columnspan=2, sticky="w", padx=3)
    labels[name] = lbl

# --- Optimized window sizing ---
root.update_idletasks()
# Single calculation instead of max() over all children
required_width = 380  # Fixed width based on layout
required_height = (len(label_configs) // 2 + 2) * 20  # Calculated height
root.geometry(f"{required_width}x{required_height}+{root.winfo_screenwidth()-required_width-10}+20")

# --- Start optimized monitoring ---
monitor_thread = threading.Thread(target=monitor_loop, daemon=True, name="SiteMoniterMain")
monitor_thread.start()

# Initial update scheduling
root.after(100, process_updates)  # Start after UI is ready

# --- Memory cleanup on exit ---
def cleanup():
    # Clear all data structures
    cache.clear()
    failure_counts.clear()
    last_check_times.clear()
    while not updates.empty():
        try:
            updates.get(block=False)
        except Empty:
            break

root.protocol("WM_DELETE_WINDOW", cleanup)
root.mainloop()