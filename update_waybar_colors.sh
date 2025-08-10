#!/bin/bash

WALLPAPER="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"
LOG_FILE="$HOME/.config/waybar/update_waybar_colors.log"

echo "[$(date)] Starting color update" >> "$LOG_FILE"

# Fallback colors (dark bg, light text, medium accent)
FALLBACK_COLORS=("#1A1A1A" "#D8DEE9" "#3B4252")

# Check if wallpaper file exists and is readable
if [ ! -f "$WALLPAPER" ] || [ ! -r "$WALLPAPER" ]; then
    echo "[$(date)] Error: Wallpaper file not found or unreadable at $WALLPAPER" >> "$LOG_FILE"
    COLOR_ARRAY=("${FALLBACK_COLORS[@]}")
else
    # Extract top 3 dominant colors using histogram after resizing and quantizing
    # Optional: Add -fuzz 2% -transparent white to exclude near-white, or similar for black
    COLORS=$(convert "$WALLPAPER" -resize 100x100\! -colors 16 -depth 8 -format %c histogram:info:- 2>> "$LOG_FILE" | \
             sort -r -n | head -n 3 | awk '{print $3}')
    readarray -t COLOR_ARRAY <<< "$COLORS"

    # Validate colors (ensure #RRGGBB format)
    valid=true
    for i in "${!COLOR_ARRAY[@]}"; do
        if ! [[ "${COLOR_ARRAY[$i]}" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
            echo "[$(date)] Error: Invalid color extracted: ${COLOR_ARRAY[$i]}" >> "$LOG_FILE"
            valid=false
            break
        fi
    done

    if ! $valid; then
        COLOR_ARRAY=("${FALLBACK_COLORS[@]}")
    fi
fi

echo "[$(date)] Raw colors extracted: ${COLOR_ARRAY[@]}" >> "$LOG_FILE"

# Function to calculate luminance (0-255)
get_luminance() {
    hex=${1#\#}
    r=$((16#${hex:0:2}))
    g=$((16#${hex:2:2}))
    b=$((16#${hex:4:2}))
    echo $(( (299 * r + 587 * g + 114 * b) / 1000 ))
}

# Sort colors by luminance (darkest to brightest)
declare -a SORTED_COLORS
while IFS= read -r line; do
    SORTED_COLORS+=("$line")
done < <(for color in "${COLOR_ARRAY[@]}"; do
    lum=$(get_luminance "$color")
    echo "$lum $color"
done | sort -n | awk '{print $2}')

# Assign roles: [0]=bg (darkest), [1]=accent (middle), [2]=text (brightest)
BG_COLOR="${SORTED_COLORS[0]}"
ACCENT_COLOR="${SORTED_COLORS[1]}"
TEXT_COLOR="${SORTED_COLORS[2]}"

echo "[$(date)] Assigned colors - BG: $BG_COLOR, Accent: $ACCENT_COLOR, Text: $TEXT_COLOR" >> "$LOG_FILE"

# Check contrast ratio between BG and Text (WCAG formula)
lum_bg=$(get_luminance "$BG_COLOR")
lum_text=$(get_luminance "$TEXT_COLOR")
l1=$(( lum_text > lum_bg ? lum_text : lum_bg ))
l2=$(( lum_text > lum_bg ? lum_bg : lum_text ))
ratio=$(echo "scale=2; ($l1 / 255 + 0.05) / ($l2 / 255 + 0.05)" | bc)

if [ "$(echo "$ratio < 4.5" | bc)" -eq 1 ]; then
    echo "[$(date)] Warning: Low contrast ($ratio:1) - falling back to defaults" >> "$LOG_FILE"
    BG_COLOR="${FALLBACK_COLORS[0]}"
    ACCENT_COLOR="${FALLBACK_COLORS[1]}"
    TEXT_COLOR="${FALLBACK_COLORS[2]}"
fi

# Convert hex to RGB for rgba() format
hex_to_rgb() {
    hex=${1#\#}
    r=$((16#${hex:0:2}))
    g=$((16#${hex:2:2}))
    b=$((16#${hex:4:2}))
    echo "$r, $g, $b"
}

RGB_BG=$(hex_to_rgb "$BG_COLOR")
RGB_ACCENT=$(hex_to_rgb "$ACCENT_COLOR")

# Update Waybar CSS
cat > "$WAYBAR_STYLE" << EOF
* {
    font-family: "JetBrainsMono", sans-serif;
    font-size: 13px;
    color: $TEXT_COLOR; /* Text color */
}

#waybar {
    background: rgba($RGB_BG, 0.8); /* Higher opacity for better visibility */
    border-bottom: 2px solid $ACCENT_COLOR;
}

#workspaces button {
    background: $ACCENT_COLOR;
    color: $TEXT_COLOR;
}

#workspaces button.focused {
    background: $TEXT_COLOR;
    color: $BG_COLOR;
}

#clock, #battery, #cpu, #memory, #network, #pulseaudio {
    background: rgba($RGB_ACCENT, 0.8); /* Higher opacity */
    color: $TEXT_COLOR;
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
