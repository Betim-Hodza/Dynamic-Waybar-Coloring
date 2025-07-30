# Dynamic-Waybar-Coloring

This is a couple of bash scripts that utitize a few tools to dynmaically update the waybar coloring with the wallpaper you're currently selected.

> **NOTE**  
>Since I do use JaKooLit's arch config the paths will be similar, 
>Just change the path to match what your current wallpaper is 
>selected to update your waybar automatically

## Installing the scripts and Dependencies

### Dependencies:
```bash
sudo pacman -S imagemagick inotify-tools
```

Simply run the `./install.sh` to put the scripts inside of `/usr/local/bin`


## Hyprland autostart
Inside of your hyprland.conf (or the specific spot where you keep autostart variables at) attach the line:

```bash
exec-once = monitor_wallpaper.sh
```

## Install.sh
```bash
#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or using sudo"
  exit 1
fi

cp monitor_wallpaper.sh /usr/local/bin/monitor_wallpaper.sh
chmod +x /usr/local/bin/monitor_wallpaper.sh

cp update_waybar_color.sh /usr/local/bin/update_waybar_color.sh
chmod +x /usr/local/bin/update_waybar_color.sh
```

## Monitor Wallpaper script
```bash
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
```

## Update waybar color script
```bash
#!/bin/bash

WALLPAPER="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"
LOG_FILE="$HOME/.config/waybar/update_waybar_colors.log"

echo "[$(date)] Starting color update" >> "$LOG_FILE"

# Check if wallpaper file exists and is readable
if [ ! -f "$WALLPAPER" ] || [ ! -r "$WALLPAPER" ]; then
    echo "[$(date)] Error: Wallpaper file not found or unreadable at $WALLPAPER" >> "$LOG_FILE"
    COLOR_ARRAY=("#1A1A1A" "#D8DEE9" "#3B4252")  # Fallback colors
else
    # Extract dominant colors (top 3 colors)
    COLORS=$(convert "$WALLPAPER" -colors 3 -unique-colors txt:- 2>> "$LOG_FILE" | tail -n +2 | awk '{print $3}' | head -n 3)
    readarray -t COLOR_ARRAY <<< "$COLORS"

    # Validate colors (ensure they match #RRGGBB format)
    for i in "${!COLOR_ARRAY[@]}"; do
        if ! [[ "${COLOR_ARRAY[$i]}" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
            echo "[$(date)] Error: Invalid color extracted: ${COLOR_ARRAY[$i]}" >> "$LOG_FILE"
            COLOR_ARRAY=("#1A1A1A" "#D8DEE9" "#3B4252")  # Fallback colors
            break
        fi
    done
fi

echo "[$(date)] Colors extracted: ${COLOR_ARRAY[@]}" >> "$LOG_FILE"

# Convert hex to RGB for rgba() format
hex_to_rgb() {
    hex=${1#\#}
    r=$((16#${hex:0:2}))
    g=$((16#${hex:2:2}))
    b=$((16#${hex:4:2}))
    echo "$r, $g, $b"
}

# Get RGB values for colors
RGB0=$(hex_to_rgb "${COLOR_ARRAY[0]}")
RGB2=$(hex_to_rgb "${COLOR_ARRAY[2]}")

# Update Waybar CSS with validated colors
cat > "$WAYBAR_STYLE" << EOF
* {
    font-family: "JetBrainsMono", sans-serif;
    font-size: 13px;
    color: ${COLOR_ARRAY[1]}; /* Text color */
}

#waybar {
    background: rgba($RGB0, 0.5); /* Semi-transparent background */
    border-bottom: 2px solid ${COLOR_ARRAY[2]};
}

#workspaces button {
    background: ${COLOR_ARRAY[2]};
    color: ${COLOR_ARRAY[1]};
}

#workspaces button.focused {
    background: ${COLOR_ARRAY[1]};
    color: ${COLOR_ARRAY[0]};
}

#clock, #battery, #cpu, #memory, #network, #pulseaudio {
    background: rgba($RGB2, 0.5); /* Semi-transparent module background */
    color: ${COLOR_ARRAY[1]};
    padding: 0 10px;
    margin: 0 5px;
}
EOF

# Check if CSS was generated successfully
if [ $? -eq 0 ]; then
    echo "[$(date)] CSS file updated successfully" >> "$LOG_FILE"
else
    echo "[$(date)] Error: Failed to update CSS file" >> "$LOG_FILE"
fi

# Restart Waybar
pkill waybar && waybar &>> "$LOG_FILE" &
echo "[$(date)] Waybar restarted" >> "$LOG_FILE"
```
