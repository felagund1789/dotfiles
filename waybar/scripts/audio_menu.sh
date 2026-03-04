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

if ! command -v pactl >/dev/null 2>&1; then
    notify "Audio" "pactl is not installed"
    exit 1
fi

if ! command -v wofi >/dev/null 2>&1; then
    notify "Audio" "wofi is not installed"
    exit 1
fi

default_sink="$(pactl get-default-sink 2>/dev/null)"

action_toggle_mute="󰝟  Toggle Mute"
action_open_pavu="󰐌  Open Pavucontrol"

menu_entries="$action_toggle_mute\n$action_open_pavu"

declare -A sink_map

sinks="$(pactl list short sinks 2>/dev/null)"
if [ -z "$sinks" ]; then
    notify "Audio" "No output devices found"
    exit 1
fi

while IFS=$'\t' read -r sink_id sink_name _; do
    [ -z "$sink_name" ] && continue

    volume="$(pactl get-sink-volume "$sink_name" 2>/dev/null | awk -F'/' 'NR==1 {gsub(/ /, "", $2); print $2}')"
    muted="$(pactl get-sink-mute "$sink_name" 2>/dev/null | awk '{print $2}')"

    if [ -z "$volume" ]; then
        volume="?%"
    fi

    icon="󰕾"
    if [ "$muted" = "yes" ]; then
        icon="󰝟"
    fi

    prefix="  "
    if [ "$sink_name" = "$default_sink" ]; then
        prefix=" "
    fi

    entry="$prefix$icon  $sink_name  $volume"

    unique_entry="$entry"
    idx=2
    while [ -n "${sink_map[$unique_entry]:-}" ]; do
        unique_entry="$entry ($idx)"
        idx=$((idx + 1))
    done

    sink_map["$unique_entry"]="$sink_name"
    menu_entries="$menu_entries\n$unique_entry"
done <<< "$sinks"

selection="$(printf '%b\n' "$menu_entries" | menu_cmd "Audio Outputs")"
[ -z "$selection" ] && exit 0

if [ "$selection" = "$action_toggle_mute" ]; then
    if pactl set-sink-mute @DEFAULT_SINK@ toggle >/tmp/audio_menu.log 2>&1; then
        state="$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')"
        if [ "$state" = "yes" ]; then
            notify "Audio" "Output muted"
        else
            notify "Audio" "Output unmuted"
        fi
        exit 0
    fi

    err="$(tail -n 1 /tmp/audio_menu.log 2>/dev/null)"
    [ -z "$err" ] && err="Failed to toggle mute"
    notify "Audio" "$err"
    exit 1
fi

if [ "$selection" = "$action_open_pavu" ]; then
    pavucontrol >/dev/null 2>&1 &
    exit 0
fi

selected_sink="${sink_map[$selection]:-}"
if [ -z "$selected_sink" ]; then
    notify "Audio" "Invalid selection"
    exit 1
fi

if ! pactl set-default-sink "$selected_sink" >/tmp/audio_menu.log 2>&1; then
    err="$(tail -n 1 /tmp/audio_menu.log 2>/dev/null)"
    [ -z "$err" ] && err="Failed to set default output"
    notify "Audio" "$err"
    exit 1
fi

while read -r input_id _; do
    [ -z "$input_id" ] && continue
    pactl move-sink-input "$input_id" "$selected_sink" >/dev/null 2>&1
done < <(pactl list short sink-inputs 2>/dev/null)

notify "Audio" "Output set to $selected_sink"
exit 0
