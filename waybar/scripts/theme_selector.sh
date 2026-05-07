#!/usr/bin/env bash

set -euo pipefail

ASSETS_DIR="$HOME/.config/waybar/themes/assets"
CONFIG_FILE="$HOME/.config/hypr/hyprland.conf"
SWAYNC_CONFIG_DIR="$HOME/.config/swaync"

declare -A THEME_IMAGES=(
    [default]="$ASSETS_DIR/theme-symbol-default.png"
    [macos]="$ASSETS_DIR/theme-symbol-macos.png"
    [windows]="$ASSETS_DIR/theme-symbol-windows.png"
)

generate_menu() {
    local theme
    for theme in default macos windows; do
        local image_path="${THEME_IMAGES[$theme]}"
        if [[ -f "$image_path" ]]; then
            echo -en "img:$image_path\x00info:$theme\x1f$theme\n"
        else
            # Fallback to text-only row if the preview image is missing.
            echo "$theme"
        fi
    done
}

SELECTED=$(generate_menu | wofi --show dmenu \
    --conf "$HOME/.config/wofi/theme_selector.conf" \
)

if [[ -z "$SELECTED" ]]; then
    exit 0
fi

if [[ "$SELECTED" == img:* ]]; then
    SELECTED="${SELECTED#img:}"
    SELECTED="$(basename "$SELECTED")"
    SELECTED="${SELECTED#theme-symbol-}"
    SELECTED="${SELECTED%.png}"
fi

sed -i "s/\$currentTheme = .*/\$currentTheme = \"$SELECTED\"/" "$CONFIG_FILE"

if [[ "$SELECTED" == "windows" ]]; then
    sed -i "s/^\s*gaps_in = .*/    gaps_in = 1/" "$CONFIG_FILE"
    sed -i "s/^\s*gaps_out = .*/    gaps_out = 0/" "$CONFIG_FILE"
    sed -i "s/^\s*rounding = .*/    rounding = 0/" "$CONFIG_FILE"
    ln -sf "$SWAYNC_CONFIG_DIR/config-windows.json" "$SWAYNC_CONFIG_DIR/config.json"
    swaync-client --reload-config
else
    sed -i "s/^\s*gaps_in = .*/    gaps_in = 5/" "$CONFIG_FILE"
    sed -i "s/^\s*gaps_out = .*/    gaps_out = 10/" "$CONFIG_FILE"
    sed -i "s/^\s*rounding = .*/    rounding = 5/" "$CONFIG_FILE"
    ln -sf "$SWAYNC_CONFIG_DIR/config-default.json" "$SWAYNC_CONFIG_DIR/config.json"
    swaync-client --reload-config
fi

# Reload hyprland
hyprctl reload
