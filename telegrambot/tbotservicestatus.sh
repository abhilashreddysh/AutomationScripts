#!/bin/bash

# Add more services as you like
services=("sshd" "smbd" "nginx" "transmission-daemon" "transmission-telegram-d")
# sort services
IFS=$'\n' services=($(sort <<<"${services[*]}"))
unset IFS

service_status=()
# get status of all services
for service in "${services[@]}"; do
    service_status+=($(systemctl is-active "$service"))
done

out=""
message=""
for i in ${!services[@]}; do
        out+="${services[$i]}: ${service_status[$i]}\n"
done
out+="\n"

message=$(printf " Systemd service status report :\n\n$out" | sed -e 's/^/  /')

/usr/local/bin/telegrambot/tbotsend.sh "$message"
