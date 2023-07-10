#!/bin/bash
source /usr/local/cust/serverconf
if [ $# -eq 0 ]
    then
        msg="No arguments supplied"
    else
        msg="$1"
        if [ -s "$2" ]
            then
            textfile="$2"
            curl -s -F chat_id="$chatid" -F document=@$textfile -F caption="$msg" https://api.telegram.org/bot"$token"/sendDocument > /dev/null 2&>1
            duration=$(( SECONDS - start ))
            rm -f $textfile
        else
            curl -s -F chat_id="$groupid" -F text="$msg" https://api.telegram.org/bot$token/sendMessage > /dev/null
            # curl -s -F chat_id="$chatid" -F text="$msg" https://api.telegram.org/bot"$token"/sendMessage > /dev/null
        fi
fi