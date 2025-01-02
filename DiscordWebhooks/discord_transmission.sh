#!/bin/bash

# Load conf
# shellcheck source=/dev/null
source /usr/local/bin/CONF_DISCORD
WEBHOOK_URL=$WEBHOOKTRANSMISSION

# Construct payload
payload=$(
    cat <<EOF
{
    "username": "$(hostname)",
    "embeds": [{
        "title": "Transmission Complete!!",
        "description":"Download Complete",
        "fields":[
            {
                "name":"Name",
                "value":"$TR_TORRENT_NAME"
            },
            {
                "name":"ID",
                "value":"$TR_TORRENT_ID"
            },
            {
                "name":"Completion Time",
                "value":"$TR_TIME_LOCALTIME"
            },
            {
                "name":"Download DIR",
                "value":"$TR_TORRENT_DIR"
            },
            {
                "name":"Download Size",
                "value":"$TR_TORRENT_BYTES_DOWNLOADED"
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

curl -H "Content-Type: application/json" -X POST -d "$payload" "$WEBHOOK_URL"
