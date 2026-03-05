#!/usr/bin/env bash

set -euo pipefail

menu() {
    wofi --dmenu \
     --insensitive \
     --matching fuzzy \
     --prompt "$1" \
     --width 520 \
     --lines 12 \
     --cache-file /dev/null
}

notify() {
    command -v notify-send >/dev/null && notify-send "Bluetooth" "$1"
}

command -v bluetoothctl >/dev/null || { notify "bluetoothctl not installed"; exit 1; }
command -v wofi >/dev/null || exit 1

while true; do

powered=$(bluetoothctl show | awk -F': ' '/Powered:/ {print $2}')

toggle="󰂲  Turn Bluetooth Off"
[ "$powered" = "no" ] && toggle="󰂯  Turn Bluetooth On"

bluetui="  Open Bluetui"

entries="$toggle\n$bluetui"

# Collect devices (connected first)
mapfile -t devices < <(
{
bluetoothctl devices Connected
bluetoothctl paired-devices
} | awk '!seen[$2]++'
)

declare -A mac_map
declare -A state_map

for d in "${devices[@]}"; do

    mac=${d#Device }
    mac=${mac%% *}

    name=${d#Device ??\:??\:??\:??\:??\:?? }
    [ -z "$name" ] && name="$mac"

    connected="no"
    bluetoothctl devices Connected | grep -q "$mac" && connected="yes"

    icon="󰂲"
    prefix="  "

    if [ "$connected" = "yes" ]; then
        icon="󰂱"
        prefix=" "
    fi

    entry="$prefix$icon  $name"

    # Query battery only for connected devices (fast)
    if [ "$connected" = "yes" ]; then
        batt=$(bluetoothctl info "$mac" | sed -n 's/.*(\([0-9]\+\)).*/\1/p' | head -n1)
        [ -n "$batt" ] && entry="$entry ${batt}%"
    fi

    entries="$entries\n$entry"

    mac_map["$entry"]="$mac"
    state_map["$entry"]="$connected"

done

choice=$(printf '%b\n' "$entries" | menu "Bluetooth")
[ -z "$choice" ] && exit 0

if [ "$choice" = "$toggle" ]; then
    if [ "$powered" = "yes" ]; then
        bluetoothctl power off && notify "Bluetooth disabled"
    else
        bluetoothctl power on && notify "Bluetooth enabled"
    fi
    continue
fi

if [ "$choice" = "$bluetui" ]; then
    kitty -e bluetui >/dev/null 2>&1 &
    exit 0
fi

mac="${mac_map[$choice]:-}"
state="${state_map[$choice]:-}"

[ -z "$mac" ] && continue

# Ensure adapter powered
[ "$powered" = "no" ] && bluetoothctl power on >/dev/null

if [ "$state" = "yes" ]; then
    bluetoothctl disconnect "$mac" && notify "Device disconnected"
else
    bluetoothctl connect "$mac" && notify "Device connected"
fi

done