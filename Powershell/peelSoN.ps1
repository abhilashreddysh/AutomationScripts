#
# -- NoSleep --
# Goal : Keep your computer awake by programmatically pressing the Scroll Lock key every X seconds
# Owner : abhilashreddysh @github
# Version : 2.3    
# Changelog : 
#               Added Context Menu to run in systemtray
#               Script will now end after the logout time
#               Ask for Hour and Minutes to end the script
#               Skip Scroll Lock toggle if there is any mouse movement between the time interval

[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')       | out-null

$icon = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\Windows\System32\mmc.exe")    

# https://stackoverflow.com/questions/40617800/opening-powershell-script-and-hide-command-prompt-but-not-the-gui
# .Net methods for hiding/showing the console in the background
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
#0 hide
[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0)

# ------------ Stopwatch -----------------

$stopwatch
# Some environments don't support invocation of this method.
try {
    $stopwatch = [system.diagnostics.stopwatch]::StartNew()
} catch {
   Write-Error  "Couldn't start the stopwatch."
}

# ------------END---------------

# https://github.com/damienvanrobaeys/Build-PS1-Systray-Tool
################################################################################################################################"
# ACTIONS FROM THE SYSTRAY
################################################################################################################################"
# ----------------------------------------------------
# Part - Add the systray menu
# ----------------------------------------------------        

$sysTrayIcon = New-Object System.Windows.Forms.NotifyIcon
$sysTrayIcon.Text = "noSleep"
$sysTrayIcon.Icon = $icon
$sysTrayIcon.Visible = $true

$Menu_Start = New-Object System.Windows.Forms.MenuItem
$Menu_Start.Enabled = $false
$Menu_Start.Text = "Start"

$Menu_Stop = New-Object System.Windows.Forms.MenuItem
$Menu_Stop.Enabled = $true
$Menu_Stop.Text = "Stop"

$Menu_Exit = New-Object System.Windows.Forms.MenuItem
$Menu_Exit.Text = "Exit"

$contextmenu = New-Object System.Windows.Forms.ContextMenu
$sysTrayIcon.ContextMenu = $contextmenu
$sysTrayIcon.contextMenu.MenuItems.AddRange($Menu_Start)
$sysTrayIcon.contextMenu.MenuItems.AddRange($Menu_Stop)
$sysTrayIcon.contextMenu.MenuItems.AddRange($Menu_Exit)

# ---------------------------------------------------------------------
# Action to keep system awake
# ---------------------------------------------------------------------

$isAliveCheck = {
    while ($true) {
        $sysTrayIcon.Text = "noSleep : Alive"
        $Wshell = New-Object -ComObject WScript.Shell
        $WShell.sendkeys("{SCROLLLOCK}")
        Start-Sleep -Milliseconds 10
        $WShell.sendkeys("{SCROLLLOCK}")
        Start-Sleep -seconds 120
    }
    $sysTrayIcon.Text = "noSleep"
}

Start-Job -ScriptBlock $isAliveCheck -Name "isAlive"

# ---------------------------------------------------------------------
# Action when after a click on the systray icon
# ---------------------------------------------------------------------
$sysTrayIcon.Add_Click({                    
    If ($_.Button -eq [Windows.Forms.MouseButtons]::Left) {
        # $sysTrayIcon.GetType().GetMethod("ShowContextMenu",[System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic).Invoke($sysTrayIcon,$null)
        $sysTrayIcon.BalloonTipText = "STATUS: ALIVE`nElapsed time: " + $stopwatch.Elapsed.ToString('dd\.hh\:mm\:ss')
        $sysTrayIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
        $sysTrayIcon.BalloonTipTitle = "Hey $Env:USERNAME"
        $sysTrayIcon.ShowBalloonTip(1500)
    }
    If ($_.Button -eq [Windows.Forms.MouseButtons]::Right) {
        $sysTrayIcon.GetType().GetMethod("ShowContextMenu",[System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic).Invoke($sysTrayIcon,$null)
    }
})

# When Start is clicked, start stayawake job and get its pid
$Menu_Start.add_Click({
    $Menu_Stop.Enabled = $true
    $Menu_Start.Enabled = $false
    Stop-Job -Name "isAlive"
    Start-Job -ScriptBlock $isAliveCheck -Name "isAlive"
 })

# When Stop is clicked, kill stay awake job
$Menu_Stop.add_Click({
    $Menu_Stop.Enabled = $false
    $Menu_Start.Enabled = $true
    Stop-Job -Name "isAlive"
 })

# When Exit is clicked, close everything and kill the PowerShell process
function KillTree {
    Param([int]$ppid)
    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $ppid } | ForEach-Object { KillTree $_.ProcessId }
    Stop-Process -Id $ppid
}
$Menu_Exit.add_Click({
    $sysTrayIcon.Visible = $false
    $sysTrayIcon.Dispose()
    Stop-Job -Name "isAlive"
    KillTree $pid
 })

# Make PowerShell Disappear [This Does not work and I have no idea why?]
$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)

# Force garbage collection just to start slightly lower RAM usage.
[System.GC]::Collect()

# Create an application context for it to all run within.
# This helps with responsiveness, especially when clicking Exit.
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)