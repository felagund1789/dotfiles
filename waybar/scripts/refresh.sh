#!/bin/bash

# Check if waybar is running
if pgrep -x "waybar" > /dev/null; then
    # If running, kill the waybar process
    pkill -x "waybar"
    sleep 0.1 # Wait for a moment to ensure the process has been killed
fi
# start waybar
waybar &
