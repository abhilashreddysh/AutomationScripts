#!/bin/bash
source /usr/local/serverconf
if [ $# -eq 0 ]
    then
        msg="No arguments supplied"
    else
        msg="🚨 **Alert from $(hostname)** 🚨"$'\n'""$'\n'"⚠️ $1"$'\n'"
		\[ $(hostname -I | awk '{print $1}') ]
		\[ $(uptime -p)]
		\[ $(date) ]"
		
        if [ -s "$2" ]
            then
            textfile="$2"
            curl -s -F chat_id="$chatid" -F document=@$textfile -F caption="$msg" -F parse_mode=markdown https://api.telegram.org/bot"$token"/sendDocument > /dev/null 2&>1
            duration=$(( SECONDS - start ))
            rm -f $textfile
        else
            curl -s -F chat_id="$groupid" -F text="$msg" -F parse_mode=markdown https://api.telegram.org/bot$token/sendMessage > /dev/null
            # curl -s -F chat_id="$chatid" -F text="$msg" https://api.telegram.org/bot"$token"/sendMessage > /dev/null
        fi
fi
