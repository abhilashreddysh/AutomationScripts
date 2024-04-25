#!/bin/bash
sudo chown -R www-data:www-data /var/www/$1/*
chmod -R 755 /var/www/$1/*