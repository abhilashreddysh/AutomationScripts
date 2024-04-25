#!/bin/bash

# Load conf
source /usr/local/bin/CONF_DISCORD
WEBHOOK_URL=$WEBHOOKPROD

# set -x
# Shell script to monitor or watch the disk space
# It will send an email to $ADMIN, if the (free available) percentage of space is >= 90%.
# --------------------------------------------------------------------------------------------------------
# Set admin email so that you can get email.
ADMIN=""
# set alert level 90% is default
ALERT=85
# Exclude list of unwanted monitoring, if several partions then use "|" to separate the partitions.
# An example: EXCLUDE_LIST="/dev/hdd1|/dev/hdc5"
EXCLUDE_LIST=""
#
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#
message=''
send_alert(){
# Construct payload for upcoming ipv6 change
payload=$(cat <<EOF
{
    "username": "$(hostname)",
    "embeds": [{
        "title": "Low Disk Space",
        "description":"$message",
        "color":"$ERROR",
        "footer": {
        "text": "$(date)"
      }
    }]
}
EOF
)
curl -H "Content-Type: application/json" -X POST -d "$payload" "$WEBHOOK_URL"
}


main_prog() {
while read -r output;
do
  #echo "Working on $output ..."
  usep=$(echo "$output" | awk '{ print $1}' | cut -d'%' -f1)
  partition=$(echo "$output" | awk '{print $2}')
  if [ $usep -ge $ALERT ] ; then
    message="Running out of disk space \n \`$partition\` ---> \`$usep%\`"
    send_alert
  fi
done
}
 
if [ "$EXCLUDE_LIST" != "" ] ; then
  df -H | grep -vE "^Filesystem|tmpfs|cdrom|${EXCLUDE_LIST}" | awk '{print $5 " " $6}' | main_prog
else
  df -H | grep -vE "^Filesystem|tmpfs|cdrom" | awk '{print $5 " " $6}' | main_prog
fi
