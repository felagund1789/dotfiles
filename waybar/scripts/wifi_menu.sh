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

signal_icon() {
    signal_value="$1"
    if [ -z "$signal_value" ]; then
        printf "󰤯"
        return
    fi

    if [ "$signal_value" -ge 80 ] 2>/dev/null; then
        printf "󰤨"
    elif [ "$signal_value" -ge 60 ] 2>/dev/null; then
        printf "󰤥"
    elif [ "$signal_value" -ge 40 ] 2>/dev/null; then
        printf "󰤢"
    elif [ "$signal_value" -ge 20 ] 2>/dev/null; then
        printf "󰤟"
    else
        printf "󰤯"
    fi
}

if ! command -v nmcli >/dev/null 2>&1; then
    notify "Wi-Fi" "nmcli is not installed"
    exit 1
fi

if ! command -v wofi >/dev/null 2>&1; then
    notify "Wi-Fi" "wofi is not installed"
    exit 1
fi

wifi_iface="$(nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: '$2=="wifi" {print $1; exit}')"

if [ -z "$wifi_iface" ]; then
    notify "Wi-Fi" "No Wi-Fi interface found"
    exit 1
fi

radio_state="$(nmcli radio wifi)"
action_toggle=""
if [ "$radio_state" = "enabled" ]; then
    action_toggle="󰖪  Turn Wi-Fi Off"
else
    action_toggle="󰖩  Turn Wi-Fi On"
fi

action_rescan="󰑐  Rescan Networks"

nmcli device wifi rescan ifname "$wifi_iface" >/dev/null 2>&1

networks_raw="$(nmcli -t --escape no --separator $'\t' -f IN-USE,SSID,BSSID,SIGNAL,SECURITY device wifi list ifname "$wifi_iface")"

menu_entries="$action_toggle\n$action_rescan"

declare -A ssid_map
declare -A bssid_map
declare -A security_map

while IFS=$'\t' read -r inuse ssid bssid signal security; do
    [ -z "$bssid" ] && continue

    if [ -z "$ssid" ]; then
        ssid="<hidden>"
    fi

    lock_icon=""
    if [ -n "$security" ] && [ "$security" != "--" ]; then
        lock_icon="󰌾"
    else
        lock_icon=" "
    fi

    wifi_icon="$(signal_icon "$signal")"

    active_prefix="  "
    if [ "$inuse" = "*" ]; then
        active_prefix=" "
    fi

    entry="$active_prefix$wifi_icon  ${signal}%  $lock_icon  $ssid"

    # Ensure uniqueness for duplicate SSIDs
    unique_entry="$entry"
    idx=2
    while [ -n "${ssid_map[$unique_entry]:-}" ]; do
        unique_entry="$entry ($idx)"
        idx=$((idx + 1))
    done

    ssid_map["$unique_entry"]="$ssid"
    bssid_map["$unique_entry"]="$bssid"
    security_map["$unique_entry"]="$security"

    menu_entries="$menu_entries\n$unique_entry"
done <<< "$networks_raw"

selection="$(printf '%b\n' "$menu_entries" | menu_cmd "Wi-Fi")"

[ -z "$selection" ] && exit 0

if [ "$selection" = "$action_toggle" ]; then
    if [ "$radio_state" = "enabled" ]; then
        nmcli radio wifi off && notify "Wi-Fi" "Wi-Fi turned off"
    else
        nmcli radio wifi on && notify "Wi-Fi" "Wi-Fi turned on"
    fi
    exit 0
fi

if [ "$selection" = "$action_rescan" ]; then
    nmcli device wifi rescan ifname "$wifi_iface" >/dev/null 2>&1
    notify "Wi-Fi" "Network scan started"
    exit 0
fi

selected_ssid="${ssid_map[$selection]:-}"
selected_bssid="${bssid_map[$selection]:-}"
selected_security="${security_map[$selection]:-}"

if [ -z "$selected_ssid" ] || [ -z "$selected_bssid" ]; then
    notify "Wi-Fi" "Invalid selection"
    exit 1
fi

if nmcli device wifi connect "$selected_ssid" ifname "$wifi_iface" bssid "$selected_bssid" >/tmp/wifi_menu_nmcli.log 2>&1; then
    notify "Wi-Fi" "Connected to $selected_ssid"
    exit 0
fi

needs_password=false
if [ -n "$selected_security" ] && [ "$selected_security" != "--" ]; then
    needs_password=true
fi

if [ "$needs_password" = true ]; then
    password="$(printf '' | menu_cmd "Password for $selected_ssid")"
    [ -z "$password" ] && exit 0

    if nmcli device wifi connect "$selected_ssid" ifname "$wifi_iface" bssid "$selected_bssid" password "$password" >/tmp/wifi_menu_nmcli.log 2>&1; then
        notify "Wi-Fi" "Connected to $selected_ssid"
        exit 0
    fi
fi

error_msg="$(tail -n 1 /tmp/wifi_menu_nmcli.log 2>/dev/null)"
[ -z "$error_msg" ] && error_msg="Could not connect to $selected_ssid"
notify "Wi-Fi" "$error_msg"
exit 1
