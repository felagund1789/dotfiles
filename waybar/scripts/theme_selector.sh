#!/bin/bash

# Display wofi with available themes
THEMES=("default" "macos" "windows")
SELECTED=$(printf '%s\n' "${THEMES[@]}" | wofi --dmenu --prompt "Select theme:")

# Exit if no selection was made
if [ -z "$SELECTED" ]; then
    exit 0
fi

# Path to hyprland config
CONFIG_FILE="$HOME/.config/hypr/hyprland.conf"

# Replace the currentTheme variable
sed -i "s/\$currentTheme = .*/\$currentTheme = \"$SELECTED\"/" "$CONFIG_FILE"

# Reload hyprland
hyprctl reload
