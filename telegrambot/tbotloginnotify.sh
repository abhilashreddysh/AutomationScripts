#!/bin/bash

# prepare any message you want
login_ip="$(echo $SSH_CONNECTION | cut -d " " -f 1)"
login_name="$(whoami)"

# Message
message=" ℹ️ New login to server user **$login_name** from $login_ip"

#send it to telegram
/usr/local/bin/telegrambot/tbotsend.sh "$message"
