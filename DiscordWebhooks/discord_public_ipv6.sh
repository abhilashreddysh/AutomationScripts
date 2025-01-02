#!/bin/bash

# Load conf
# shellcheck source=/dev/null
source /usr/local/bin/CONF_DISCORD
WEBHOOK_URL=$WEBHOOKIPCHGALERT

# ipv6_deprecated=($(ip -6 addr | grep deprecated | awk '{print $2}' | grep -P '^(?!fe80)[[:alnum:]]{4}:.*/64' | cut -d '/' -f1))
mapfile -t ipv6_deprecated < <(ip -6 addr | grep deprecated | awk '{print $2}' | grep -P '^(?!fe80)[[:alnum:]]{4}:.*/64' | cut -d '/' -f1)
ipv6=$(ip -6 addr | grep -v deprecated | awk '{print $2}' | grep -P '^(?!fe80)[[:alnum:]]{4}:.*/64' | cut -d '/' -f1)
recorded_ipv6=$(cat /tmp/publicipv6) || echo "File_Missing"

if [ ${#ipv6_deprecated[@]} -ge 1 ]; then
    {
        # Construct payload for upcoming ipv6 change
        payload=$(
            cat <<EOF
{
    "username": "$(hostname)",
    "embeds": [{
        "title": "IPv6 Change Alert",
        "description":"Public IPv6 is going to change in a while",
        "fields":[
            {
                "name":"New IPv6",
                "value":"$ipv6"
            },
            {
                "name":"Old IPv6",
                "value":"$(printf '%s\n' "${ipv6_deprecated[*]}")"
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
    }
fi
if [[ $recorded_ipv6 != "$ipv6" ]]; then
    # Construct payload for upcoming ipv6 change
    payload=$(
        cat <<EOF
{
    "username": "$(hostname)",
    "embeds": [{
        "title": "IPv6 Changed",
        "description":"Public IPv6 is changed",
        "fields":[
            {
                "name":"Public IPv6",
                "value":"$ipv6"
            }
        ],
        "color":"$WARN",
        "footer": {
        "text": "$(date)"
      }
    }]
}
EOF
    )
    curl -H "Content-Type: application/json" -X POST -d "$payload" "$WEBHOOK_URL"
    echo "$ipv6" >/tmp/publicipv6
fi
