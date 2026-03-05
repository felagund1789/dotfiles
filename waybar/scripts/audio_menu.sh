#!/usr/bin/env bash

set -euo pipefail

menu() {
    wofi --dmenu --insensitive --prompt "$1" --matching fuzzy --width 520 --lines 12
}

notify() {
    command -v notify-send >/dev/null && notify-send "Audio" "$1"
}

command -v pactl >/dev/null || { notify "pactl not installed"; exit 1; }
command -v wofi >/dev/null || exit 1

device_icon() {
    case "$1" in
        *bluez*) echo "󰂯" ;;      # Bluetooth
        *hdmi*) echo "󰍹" ;;       # HDMI / monitor
        *headphone*|*headset*) echo "󰋋" ;;
        *speaker*) echo "󰓃" ;;
        *) echo "󰕾" ;;
    esac
}

while true; do

default_sink=$(pactl get-default-sink)

toggle="󰝟  Toggle Mute"
pavu="󰐌  Open Pavucontrol"

entries="$toggle\n$pavu"

mapfile -t sinks < <(pactl list short sinks)

declare -A sink_map

for s in "${sinks[@]}"; do

    IFS=$'\t' read -r id name driver _ <<< "$s"

    vol=$(pactl get-sink-volume "$name" | awk -F'/' 'NR==1{gsub(/ /,"",$2);print $2}')
    mute=$(pactl get-sink-mute "$name" | awk '{print $2}')

    icon=$(device_icon "$name")
    [ "$mute" = "yes" ] && icon="󰝟"

    prefix="  "
    [ "$name" = "$default_sink" ] && prefix=" "

    label=$(sed \
        -e 's/alsa_output\.//g' \
        -e 's/bluez_output\.//g' \
        -e 's/\.analog-stereo//g' \
        -e 's/_/ /g' <<< "$name")

    entry="$prefix$icon  $label  ${vol:-?%}"

    entries="$entries\n$entry"
    sink_map["$entry"]="$name"

done

choice=$(printf '%b\n' "$entries" | menu "Audio Output")
[ -z "$choice" ] && exit 0

if [ "$choice" = "$toggle" ]; then
    pactl set-sink-mute @DEFAULT_SINK@ toggle
    state=$(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}')
    [ "$state" = "yes" ] && notify "Output muted" || notify "Output unmuted"
    continue
fi

if [ "$choice" = "$pavu" ]; then
    pavucontrol >/dev/null 2>&1 &
    exit 0
fi

sink="${sink_map[$choice]:-}"
[ -z "$sink" ] && continue

pactl set-default-sink "$sink"

while read -r input _; do
    pactl move-sink-input "$input" "$sink"
done < <(pactl list short sink-inputs)

notify "Output switched"

done