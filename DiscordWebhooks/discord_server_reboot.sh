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
    "title": "Server Online",
    "description":"Server Reboot Successful",
    "fields":[
      {
        "name":"Public IPv6",
        "value":"$(ip -6 addr | awk '{print $2}' | grep -P '^(?!fe80)[[:alnum:]]{4}:.*/64' | cut -d '/' -f1)"
      }
    ],
    "color":"$SUCCESS",
    "footer": {
    "text": "$(date)"
    }
  }]
}
EOF
)

ip -6 addr | awk '{print $2}' | grep -P '^(?!fe80)[[:alnum:]]{4}:.*/64' | cut -d '/' -f1 >/tmp/publicipv6

curl -H "Content-Type: application/json" -X POST -d "$payload" "$WEBHOOK_URL"
