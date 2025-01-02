#!/bin/bash

# Load server configuration (e.g., Telegram Bot Token, Chat IDs)
source /usr/local/bin/serverconf

# Default values for group chat and personal chat
group_chat=false
personal_chat=false
textfile=""

# Parse options
while getopts "gpd:" opt; do
  case $opt in
    g)  # Send to group chat
      group_chat=true
      ;;
    p)  # Send to personal chat
      personal_chat=true
      ;;
    d)  # Send file to Telegram
      textfile="$OPTARG"
      ;;
    \?)  # Invalid option
      echo "Usage: -g for group chat, -p for personal chat, -d for file."
      exit 1
      ;;
  esac
done

# Remove the options like -g and -p from the message content
shift $((OPTIND - 1))  # This will shift the positional arguments to the right
msg="$1"  # Get the actual message from the first argument after options

# Get the IPv6 address if available, specifically public and not link-local
ip_address=$(hostname -I | awk '{print $1}')
# Check for IPv6 address, excluding the loopback (::1) and link-local (fe80) addresses
if ip -6 addr show | grep -q "inet6" && ! ip -6 addr show | grep -q "fe80" && ! ip -6 addr show | grep -q "::1"; then
  ip_address=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d '/' -f1 | head -n 1)
fi

# Function to get public IPv6 address
get_public_ipv6() {
  ip -6 addr | awk '{print $2}' | grep -P '^(?!fe80)[[:alnum:]]{4}:.*/64' | cut -d '/' -f1 | head -n 1
}

# Fetch public IPv6 address
ip_address=$(get_public_ipv6)

# Construct the message
msg=$(cat <<EOF
<b>🚨 Server Alert: $(hostname)</b>

<pre>
<b>⚠️ Event:</b> <i>System Reboot Successful</i> 🎉

</pre>

<b>🌐 IP Address:</b> <code>$ip_address</code>
<b>⏳ Uptime Before Reboot:</b> <code>$(uptime -p)</code>
<b>📅 Reboot Time:</b> <code>$(date)</code>

<b>🔧 Actions Taken:</b>
<i>System rebooted successfully. All services are back online.</i>

<b>📍 Server Status:</b>
• OS: $(uname -o)
• Kernel: $(uname -r)
• Architecture: $(uname -m)


<b>🔗 Go to Dashboard:</b>
EOF
)



# Function to send message
send_message() {
  local chat_id="$1"
  curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
     -d "chat_id=$chat_id" \
     -d "text=$msg" \
     -d "parse_mode=HTML" \
     -d "reply_markup={\"inline_keyboard\":[[{\"text\":\"Go to Dashboard\",\"url\":\"http://www.localhost:8000/docs\"}]]}" > /dev/null
     }

# Send message based on flags
if [ "$group_chat" = true ]; then
  send_message "$groupid"
elif [ "$personal_chat" = true ]; then
  send_message "$personal_chat_id"
elif [ -n "$textfile" ]; then
  if [ -s "$textfile" ]; then
    curl -s -X POST "https://api.telegram.org/bot$token/sendDocument" \
         -F "chat_id=$groupid" \
         -F "document=@$textfile" \
         -F "caption=$msg" \
         -F "parse_mode=HTML" > /dev/null
  else
    echo "File is empty or not found."
  fi
else
  echo "No chat specified. Use -g for group or -p for personal chat."
fi