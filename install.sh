#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or using sudo"
  exit 1
fi

cp monitor_wallpaper.sh /usr/local/bin/monitor_wallpaper.sh
chmod +x /usr/local/bin/monitor_wallpaper.sh

cp update_waybar_colors.sh /usr/local/bin/update_waybar_colors.sh
chmod +x /usr/local/bin/update_waybar_colors.sh
