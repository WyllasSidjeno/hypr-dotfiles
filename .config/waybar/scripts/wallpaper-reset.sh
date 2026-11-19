#!/usr/bin/env bash
systemctl --user restart hyprpaper.service
notify-send -a waybar "Wallpaper" "hyprpaper restarted"
