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

