#!/bin/bash

# Kill any running waybar instances.
if pgrep -x "waybar" >/dev/null; then
    pkill -x "waybar"

    # Wait until all waybar processes have exited before relaunching.
    while pgrep -x "waybar" >/dev/null; do
        sleep 0.1
    done
fi

# Start waybar in the background.
waybar &

# Kill any running swaync instances.
if pgrep -x "swaync" >/dev/null; then
    pkill -x "swaync"

    # Wait until all swaync processes have exited before relaunching.
    while pgrep -x "swaync" >/dev/null; do
        sleep 0.1
    done
fi

# Start swaync in the background.
swaync &
