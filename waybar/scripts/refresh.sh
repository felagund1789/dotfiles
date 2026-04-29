#!/bin/bash

# refresh swaync configuration and style.
swaync-client --reload-config
swaync-client --reload-css 

# Kill any running waybar instances.
if pgrep -x "waybar" >/dev/null; then
    pkill -x "waybar"

    # Wait until all waybar processes have exited before relaunching.
    while pgrep -x "waybar" >/dev/null; do
        sleep 0.1
    done
fi

# Start waybar in the background.
waybar --style ~/.config/waybar/macos-style.css &
