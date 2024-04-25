#!/bin/bash

# Load conf
source /usr/local/bin/CONF_DISCORD
WEBHOOK_URL=$WEBHOOKDEV

# Construct payload
payload=$(cat <<EOF
{
    "username": "$(hostname)",
    "content":"```$1```"
}
EOF
)
# payload=$(cat <<EOF
# {
#     "username": "$(hostname)",
#     "embeds": [{
#         "title": "Message",
#         "description":"$1",
#         "color":"$SUCCESS",
#         "footer": {
#         "text": "$(date)"
#       }
#     }]
# }
# EOF
# )

curl -H "Content-Type: application/json" -X POST -d "$payload" "$WEBHOOK_URL"
