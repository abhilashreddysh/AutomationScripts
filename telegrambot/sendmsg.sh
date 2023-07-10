#!/bin/bash
#This script monitors server load and memory usage for every 10 seconds and sends notification to telegram in case of high usage.

#Include telegram chat id and bot token ID here
chat_id="1246409037"
token="5864339399:AAHthA5UaUv2qjuesQ4suHp6pe1pmm85GX8"

#Temporary files to store data
resource_usage_info=/tmp/resource_usage_info.txt
msg_caption=/tmp/telegram_msg_caption.txt

#Set threshold levels for memory usage and load here. If the usage exceeds these values, the notification will be sent.
mem_threshold=20 #Should be interger. This is in percentage
load_threshold=$(nproc) #Should be integer. Usually total number of cores.

#Telegram API to send notificaiton.
function telegram_send
{
curl -s -F chat_id=$chat_id -F document=@$resource_usage_info -F caption="$caption" https://api.telegram.org/bot$token/sendDocument > /dev/null 2&>1
}

#Monitoring Load on the server
while :
do
    min_load=$(cat /proc/loadavg | cut -d . -f1)
    if [ $min_load -ge $load_threshold ]
        then
        echo -e "High CPU usage detected on $(hostname)\n$(uptime)" > $msg_caption
        echo -e "CPU usage report from $(hostname)\nServer Time : $(date +"%d%b%Y %T")\n\n\$uptime\n$(uptime)\n\n%CPU %MEM USER\tCMD" >         $resource_usage_info
        ps -eo pcpu,pmem,user,cmd | sed '1d' | sort -nr >> $resource_usage_info
        caption=$(<$msg_caption)
        telegram_send
        rm -f $resource_usage_info
        rm -f $msg_caption
        sleep 900 #stop executing script for 15 minutes
    fi
    sleep 10

#Monitoring Memory usage on the server
    mem=$(free -m)
    mem_usage=$(echo "$mem" | awk 'NR==2{printf "%i\n", ($3*100/$2)}')
    if [ $mem_usage -gt $mem_threshold ]
    then
        echo -e "High Memory usage detected on $(hostname)\n$(echo $mem_usage% memory usage)" > $msg_caption
        echo -e "Memory consumption Report from $(hostname)\nServer Time : $(date +"%d%b%Y %T")\n\n\$free -m output\n$mem\n\n%MEM %CPU USER\tCMD" > $resource_usage_info
        ps -eo pmem,pcpu,user,cmd | sed '1d' | sort -nr >> $resource_usage_info
        caption=$(<$msg_caption)
        telegram_send
        rm -f $resource_usage_info
        rm -f $msg_caption
        sleep 900 #stop executing script for 15 minutes
    fi
    sleep 10
done
