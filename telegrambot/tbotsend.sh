#!/bin/bash
source /usr/local/bin/serverconf

group_chat=false
personal_chat=false
textfile=""

# the colon (:) after the letter indicates that the args require a value to be passed else the script will reject it
while getopts "t:gpd:" opt; do
  case $opt in
    g)
      group_chat=true
      ;;
    p)
      personal_chat=true
      ;;
    d)
    textfile="$OPTARG"
      if [ -s "$textfile" ]
        curl -s -F chat_id="$chatid" -F document=@$textfile -F caption="$msg" -F parse_mode=markdown https://api.telegram.org/bot"$token"/sendDocument > /dev/null 2&>1
        duration=$(( SECONDS - start ))
        rm -f $textfile
      else
        pass
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

main () {
msg="🚨 **Alert from $(hostname)** 🚨"$'\n'""$'\n'"⚠️ $1"$'\n\n-------------------------\n'"\[ $(uptime -p)] \[ $(hostname -I | awk '{print $1}') ] \[ $(date) ]"

}

# if [ $# -eq 0 ]
#     then
#         msg="No arguments supplied"
#     else
#         msg="🚨 **Alert from $(hostname)** 🚨"$'\n'""$'\n'"⚠️ $1"$'\n\n-------------------------\n'"\[ $(uptime -p)] \[ $(hostname -I | awk '{print $1}') ] \[ $(date) ]"
		
#         if [ -s "$2" ]
#             then
#             textfile="$2"
#             curl -s -F chat_id="$chatid" -F document=@$textfile -F caption="$msg" -F parse_mode=markdown https://api.telegram.org/bot"$token"/sendDocument > /dev/null 2&>1
#             duration=$(( SECONDS - start ))
#             rm -f $textfile
#         else
#             curl -s -F chat_id="$groupid" -F text="$msg" -F parse_mode=markdown https://api.telegram.org/bot$token/sendMessage > /dev/null
#             # curl -s -F chat_id="$chatid" -F text="$msg" https://api.telegram.org/bot"$token"/sendMessage > /dev/null
#         fi
# fi
