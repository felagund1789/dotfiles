#!/usr/bin/env bash

set -euo pipefail

menu() {
    wofi --dmenu --insensitive --prompt "$1" --matching fuzzy --width 800 --lines 6 --cache-file /dev/null
}

notify() {
    command -v notify-send >/dev/null && notify-send "Wi-Fi" "$1" -i "network-wireless"
}

signal_icon() {
    s=${1:-0}
    if   ((s>=80)); then echo "󰤨 "
    elif ((s>=60)); then echo "󰤥 "
    elif ((s>=40)); then echo "󰤢 "
    elif ((s>=20)); then echo "󰤟 "
    else echo "󰤯 "
    fi
}

iface=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1;exit}')
[ -z "$iface" ] && { notify "No Wi-Fi interface"; exit 1; }

while true; do

wifi_state=$(nmcli radio wifi)
toggle="󰖪  Turn Wi-Fi Off"
[ "$wifi_state" = "disabled" ] && toggle="󰖩  Turn Wi-Fi On"

rescan="󰑐  Rescan Networks"

notify "Scanning for Wi-Fi networks..."
mapfile -t nets < <(nmcli -t -f IN-USE,SSID,SIGNAL device wifi list ifname "$iface")

options="$toggle\n$rescan"
entries=""
declare -A map

for n in "${nets[@]}"; do
    IFS=: read -r inuse ssid signal sec <<< "$n"

    [ -z "$ssid" ] && ssid="<hidden>"

    icon=$(signal_icon "$signal")

    prefix="  "
    [ "$inuse" = "*" ] && prefix="✓ "

    e="$prefix$icon ${signal}% $ssid"

    entries="$entries\n$e"

    map["$e"]="$ssid"
done

choice=$(printf '%b\n' "$options$entries" | menu "Wi-Fi")
[ -z "$choice" ] && exit 0

if [ "$choice" = "$toggle" ]; then
    if [ "$wifi_state" = "enabled" ]; then
        nmcli radio wifi off && notify "Wi-Fi disabled"
    else
        nmcli radio wifi on && notify "Wi-Fi enabled"
    fi
    continue
fi

[ "$choice" = "$rescan" ] && { nmcli device wifi rescan ifname "$iface" >/dev/null 2>&1; continue; }

ssid="${map[$choice]:-}"
[ -z "$ssid" ] && continue

if nmcli device wifi connect "$ssid" ifname "$iface" >/tmp/wifi.log 2>&1; then
    notify "Connected to $ssid"
    exit 0
fi

pass=$(printf "" | menu "Password for $ssid")
[ -z "$pass" ] && continue

if nmcli device wifi connect "$ssid" password "$pass" ifname "$iface" >/tmp/wifi.log 2>&1; then
    notify "Connected to $ssid"
else
    notify "Connection failed"
fi

done