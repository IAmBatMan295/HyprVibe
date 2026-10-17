#!/usr/bin/env bash

active=$(powerprofilesctl get)

c_active=""
c_dim=""
if [[ -f "${HOME}/.local/state/hyprvibe/current/colors.toml" ]]; then
  c_active=$(grep -m1 '^foreground' "${HOME}/.local/state/hyprvibe/current/colors.toml" | cut -d'"' -f2 || true)
  c_dim=$(grep -m1 '^muted' "${HOME}/.local/state/hyprvibe/current/colors.toml" | cut -d'"' -f2 || true)
elif command -v hyprvibe-theme >/dev/null 2>&1; then
  c_active=$(hyprvibe-theme get foreground 2>/dev/null || true)
  c_dim=$(hyprvibe-theme get muted 2>/dev/null || true)
fi
[[ -z "$c_active" ]] && c_active="#ffffff"
[[ -z "$c_dim" ]] && c_dim="#8e8e8e"

c_perf="$c_dim"
c_bal="$c_dim"
c_save="$c_dim"

[[ "$active" == "performance" ]] && c_perf="$c_active"
[[ "$active" == "balanced" ]] && c_bal="$c_active"
[[ "$active" == "power-saver" ]] && c_save="$c_active"

PERF="<span color=\"$c_perf\">  Performance</span>"
BAL="<span color=\"$c_bal\">  Balanced</span>"
SAVE="<span color=\"$c_save\">󰤄  Power Saver</span>"

rofi_cmd() {
  rofi -dmenu \
    -p "Profile ($active)" \
    -markup-rows \
    -theme-str 'listview { lines: 3; }' \
    -theme ~/.config/rofi/powermenu.rasi
}

run_rofi() {
  echo -e "$PERF\n$BAL\n$SAVE" | rofi_cmd
}

run_cmd() {
  case $1 in
  --performance)
    powerprofilesctl set performance
    notify-send -t 3000 "Power Profile" "Set to  Performance Mode"
    ;;
  --balanced)
    powerprofilesctl set balanced
    notify-send -t 3000 "Power Profile" "Set to   Balanced Mode"
    ;;
  --power-saver)
    powerprofilesctl set power-saver
    notify-send -t 3000 "Power Profile" "Set to 󰤄 Power Saver Mode"
    
    STATE=$(hyprctl getoption misc.vrr -j 2>/dev/null | grep '"int": 0' || true)
    if [ -z "$STATE" ]; then
        MON_INFO=$(hyprctl monitors -j 2>/dev/null || true)
        OUTPUT=$(echo "$MON_INFO" | jq -r '.[0].name // empty' 2>/dev/null || true)
        WIDTH=$(echo "$MON_INFO" | jq -r '.[0].width // empty' 2>/dev/null || true)
        HEIGHT=$(echo "$MON_INFO" | jq -r '.[0].height // empty' 2>/dev/null || true)
        SCALE=$(echo "$MON_INFO" | jq -r '.[0].scale // 1.0' 2>/dev/null || true)

        if [[ -n "$OUTPUT" && -n "$WIDTH" && -n "$HEIGHT" ]]; then
            if hyprctl eval "hl.monitor({ output = \"${OUTPUT}\", mode = \"${WIDTH}x${HEIGHT}@60\", position = \"auto\", scale = ${SCALE} })" > /dev/null 2>&1 && hyprctl eval 'hl.config({ misc = { vrr = 0 } })' > /dev/null 2>&1; then
                notify-send -t 4000 "Power Saver Active" "Refresh rate locked to 60Hz (${OUTPUT})"
            else
                notify-send -u critical "Power Saver Active" "Failed to lock refresh rate to 60Hz on ${OUTPUT}"
            fi
        fi
    fi
    ;;
  esac
}

chosen="$(run_rofi)"

case "$chosen" in
	*"Performance"*)
	  run_cmd --performance
	  ;;
	*"Balanced"*)
	  run_cmd --balanced
	  ;;
	*"Power Saver"*)
	  run_cmd --power-saver
	  ;;
esac
