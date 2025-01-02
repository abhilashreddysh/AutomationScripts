#!/bin/bash

# Load conf
# shellcheck source=/dev/null
source /usr/local/bin/CONF_DISCORD
WEBHOOK_URL=$WEBHOOKPROD

# Construct payload
payload=$(
    cat <<EOF
{
    "username": "$(hostname)",
    "embeds": [{
        "title": "Login Alert",
        "description":"New Login detected",
        "fields":[
            {
                "name":"User",
                "value":"$(whoami)",
                "inline":"true"
            },
            {
                "name":"Port",
                "value":"$(echo "$SSH_CONNECTION" | awk '{print $4}')",
                "inline":"true"
            },
            {
                "name":"Login IP",
                "value":"$(echo "$SSH_CONNECTION" | awk '{print $1}')"
            },
            {
                "name":"Server IPv6",
                "value":"$(ip -6 addr | awk '{print $2}' | grep -P '^(?!fe80)[[:alnum:]]{4}:.*/64' | cut -d '/' -f1)"
            }
        ],
        "color":"$WARN",
        "footer": {
        "text": "$(uptime -p)\n$(date)"
      }
    }]
}
EOF
)

curl -H "Content-Type: application/json" -X POST -d "$payload" "$WEBHOOK_URL"
