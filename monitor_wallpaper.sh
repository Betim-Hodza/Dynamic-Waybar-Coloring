#!/bin/bash

WALLPAPER_FILE="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
UPDATE_SCRIPT="update_waybar_colors.sh"

# Ensure the wallpaper file exists
if [ ! -f "$WALLPAPER_FILE" ]; then
    echo "Wallpaper file not found at $WALLPAPER_FILE"
    exit 1
fi

# Run the update script once at startup
"$UPDATE_SCRIPT"

# Monitor for changes to .wallpaper_current
inotifywait -m "$WALLPAPER_FILE" -e modify -e create |
while read -r directory events filename; do
    echo "Wallpaper changed at $WALLPAPER_FILE, updating Waybar colors..."
    "$UPDATE_SCRIPT"
done

