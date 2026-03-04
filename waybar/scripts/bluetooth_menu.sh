#!/usr/bin/env bash

set -u

menu_cmd() {
    wofi --dmenu --insensitive --prompt "$1"
}

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$1" "$2"
    fi
}

if ! command -v bluetoothctl >/dev/null 2>&1; then
    notify "Bluetooth" "bluetoothctl is not installed"
    exit 1
fi

if ! command -v wofi >/dev/null 2>&1; then
    notify "Bluetooth" "wofi is not installed"
    exit 1
fi

powered="$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}')"

if [ "$powered" = "yes" ]; then
    action_power="󰂲  Turn Bluetooth Off"
else
    action_power="󰂯  Turn Bluetooth On"
fi

action_open_bluetui="  Open Bluetui"

connected_list="$(bluetoothctl devices Connected 2>/dev/null)"
paired_list="$(bluetoothctl paired-devices 2>/dev/null)"

menu_entries="$action_power\n$action_open_bluetui"

declare -A entry_mac
declare -A entry_connected

collect_lines="$(printf '%s\n%s\n' "$connected_list" "$paired_list" | awk '!seen[$2]++')"

while IFS= read -r line; do
    [ -z "$line" ] && continue

    mac="$(printf '%s\n' "$line" | awk '{print $2}')"
    name="$(printf '%s\n' "$line" | cut -d' ' -f3-)"

    [ -z "$mac" ] && continue
    [ -z "$name" ] && name="$mac"

    info="$(bluetoothctl info "$mac" 2>/dev/null)"
    connected="$(printf '%s\n' "$info" | awk -F': ' '/Connected:/ {print $2; exit}')"
    battery="$(printf '%s\n' "$info" | sed -n 's/.*Battery Percentage:.*(\([0-9][0-9]*\)).*/\1/p' | head -n 1)"

    state_icon="󰂲"
    state_text=""
    if [ "$connected" = "yes" ]; then
        state_icon="󰂱"
        state_text=" connected"
    fi

    battery_text=""
    if [ -n "$battery" ]; then
        battery_text=" ${battery}%"
    fi

    short_mac="${mac##*:}"
    entry="$state_icon  $name$battery_text  [$short_mac]$state_text"

    unique_entry="$entry"
    idx=2
    while [ -n "${entry_mac[$unique_entry]:-}" ]; do
        unique_entry="$entry ($idx)"
        idx=$((idx + 1))
    done

    entry_mac["$unique_entry"]="$mac"
    entry_connected["$unique_entry"]="$connected"
    menu_entries="$menu_entries\n$unique_entry"
done <<< "$collect_lines"

selection="$(printf '%b\n' "$menu_entries" | menu_cmd "Bluetooth")"
[ -z "$selection" ] && exit 0

if [ "$selection" = "$action_power" ]; then
    if [ "$powered" = "yes" ]; then
        if bluetoothctl power off >/tmp/bluetooth_menu.log 2>&1; then
            notify "Bluetooth" "Bluetooth turned off"
            exit 0
        fi
    else
        if bluetoothctl power on >/tmp/bluetooth_menu.log 2>&1; then
            notify "Bluetooth" "Bluetooth turned on"
            exit 0
        fi
    fi

    err="$(tail -n 1 /tmp/bluetooth_menu.log 2>/dev/null)"
    [ -z "$err" ] && err="Failed to toggle bluetooth power"
    notify "Bluetooth" "$err"
    exit 1
fi

if [ "$selection" = "$action_open_bluetui" ]; then
    kitty -e bluetui >/dev/null 2>&1 &
    exit 0
fi

selected_mac="${entry_mac[$selection]:-}"
selected_connected="${entry_connected[$selection]:-}"

if [ -z "$selected_mac" ]; then
    notify "Bluetooth" "Invalid selection"
    exit 1
fi

if [ "$powered" != "yes" ]; then
    if ! bluetoothctl power on >/tmp/bluetooth_menu.log 2>&1; then
        err="$(tail -n 1 /tmp/bluetooth_menu.log 2>/dev/null)"
        [ -z "$err" ] && err="Failed to power on bluetooth"
        notify "Bluetooth" "$err"
        exit 1
    fi
fi

if [ "$selected_connected" = "yes" ]; then
    if bluetoothctl disconnect "$selected_mac" >/tmp/bluetooth_menu.log 2>&1; then
        notify "Bluetooth" "Device disconnected"
        exit 0
    fi

    err="$(tail -n 1 /tmp/bluetooth_menu.log 2>/dev/null)"
    [ -z "$err" ] && err="Failed to disconnect device"
    notify "Bluetooth" "$err"
    exit 1
fi

if bluetoothctl connect "$selected_mac" >/tmp/bluetooth_menu.log 2>&1; then
    notify "Bluetooth" "Device connected"
    exit 0
fi

err="$(tail -n 1 /tmp/bluetooth_menu.log 2>/dev/null)"
[ -z "$err" ] && err="Failed to connect device"
notify "Bluetooth" "$err"
exit 1
