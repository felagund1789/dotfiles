#!/bin/bash

# refresh swaync configuration and style.
swaync-client --reload-config
swaync-client --reload-css 

# refresh waybar configuration and style.
kill -SIGUSR2 $(pgrep -x "waybar") 2>/dev/null
