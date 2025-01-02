#!/bin/bash

# Load conf
# shellcheck source=/dev/null
source /usr/local/bin/CONF_DISCORD
WEBHOOK_URL=$WEBHOOKDEV

# sort services
# IFS=$'\n' services=($(sort <<<"${services[*]}"))
# unset IFS
mapfile -t services < <(printf "%s\n" "${services[@]}" | sort)

service_status=()
# get status of all services
for service in "${services[@]}"; do
    service_status+=("$(systemctl is-active "$service")")
done

out=""
for i in "${!services[@]}"; do
    colorcode="$WARN"
    [[ ${service_status[$i]} == "active" ]] && colorcode="$SUCCESS" || colorcode="$ERROR"
    out+="{\"title\":\"Service : ${services[$i]}\nStatus : ${service_status[$i]}\",\"color\":$colorcode},"
done

# To remove the last comma from the out to form proper JSON
out="${out%?}"

# Construct Payload
payload=$(
    cat <<EOF
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
