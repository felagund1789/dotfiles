#!/usr/bin/env bash

set -euo pipefail

menu() {
    wofi --dmenu --insensitive --prompt "$1" --matching fuzzy --width 520 --lines 15
}

notify() {
    command -v notify-send >/dev/null && notify-send "Wi-Fi" "$1"
}

signal_icon() {
    s=${1:-0}
    if   ((s>=80)); then echo "󰤨"
    elif ((s>=60)); then echo "󰤥"
    elif ((s>=40)); then echo "󰤢"
    elif ((s>=20)); then echo "󰤟"
    else echo "󰤯"
    fi
}

iface=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1;exit}')
[ -z "$iface" ] && { notify "No Wi-Fi interface"; exit 1; }

while true; do

wifi_state=$(nmcli radio wifi)
toggle="󰖪  Turn Wi-Fi Off"
[ "$wifi_state" = "disabled" ] && toggle="󰖩  Turn Wi-Fi On"

rescan="󰑐  Rescan Networks"

mapfile -t nets < <(
nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list ifname "$iface" |
sort -t: -k3 -nr |
awk -F: '!seen[$2]++'
)

entries="$toggle\n$rescan"
declare -A map

for n in "${nets[@]}"; do
    IFS=: read -r inuse ssid signal sec <<< "$n"

    [ -z "$ssid" ] && ssid="<hidden>"

    icon=$(signal_icon "$signal")
    lock=""
    [[ "$sec" != "" && "$sec" != "--" ]] && lock="󰌾"

    prefix="  "
    [ "$inuse" = "*" ] && prefix=" "

    e="$prefix$icon ${signal}% $lock  $ssid"

    if [ "$inuse" = "*" ]; then
        entries="$toggle\n$rescan\n$e\n${entries#*$'\n'}"
    else
        entries="$entries\n$e"
    fi

    map["$e"]="$ssid"
done

choice=$(printf '%b\n' "$entries" | menu "Wi-Fi")
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