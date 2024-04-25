#!/bin/bash

# Load conf
source /usr/local/bin/CONF_DISCORD
WEBHOOK_URL=$WEBHOOKPROD

# Add more services as you like
services=("sshd" "smbd" "nginx" "transmission-daemon" "transmission-telegram-d" "pihole-FTL" "ufw")
# sort services
IFS=$'\n' services=($(sort <<<"${services[*]}"))
unset IFS

service_status=()
# get status of all services
for service in "${services[@]}"; do
    service_status+=($(systemctl is-active "$service"))
done

out=""
message=""
for i in ${!services[@]}; do
        colorcode="$WARN"
        [[ ${service_status[$i]} == "active" ]] && colorcode="$SUCCESS" || colorcode="$ERROR"
        out+="{\""title"\":\"Service : "${services[$i]}"\nStatus : "${service_status[$i]}"\",\""color"\":"$colorcode"},"
done

out=$(echo "$out"| sed 's/.$//')


# Construct Payload
payload=$(cat <<EOF
{
    "username": "$(hostname)",
    "title": "Status Alert",
    "description":"Service Status Alert",
    "embeds": [$out]
}
EOF
)

curl -H "Content-Type: application/json" -X POST -d "$payload" "$WEBHOOK_URL"


# Other Formats
# out+="{\""title"\":\"Service : "${services[$i]}"\nStatus : "${service_status[$i]}"\",\""color"\":"$colorcode",\""footer"\": {\""text"\": \""${service_status[$i]}"\"}},"