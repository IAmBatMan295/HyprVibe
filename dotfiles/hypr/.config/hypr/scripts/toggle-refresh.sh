#!/usr/bin/env bash

# Fetch active monitor info dynamically
MON_INFO=$(hyprctl monitors -j 2>/dev/null || true)
if [[ -z "$MON_INFO" || "$MON_INFO" == "[]" ]]; then
    notify-send -u critical "Screen Mode" "No active monitor found / Not supported on this display"
    exit 1
fi

OUTPUT=$(echo "$MON_INFO" | jq -r '.[0].name // empty' 2>/dev/null || true)
WIDTH=$(echo "$MON_INFO" | jq -r '.[0].width // 2880' 2>/dev/null || true)
HEIGHT=$(echo "$MON_INFO" | jq -r '.[0].height // 1800' 2>/dev/null || true)
SCALE=$(echo "$MON_INFO" | jq -r '.[0].scale // 1.8' 2>/dev/null || true)

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="eDP-1"
fi

# Fetch current vrr state (0 = off, 1 = on, 2 = fullscreen)
STATE=$(hyprctl getoption misc.vrr -j 2>/dev/null | grep '"int": 0' || true)

if [ -n "$STATE" ]; then
    # Currently 0 (off, 60Hz locked). Switch to 120Hz VRR.
    if hyprctl eval "hl.monitor({ output = \"${OUTPUT}\", mode = \"${WIDTH}x${HEIGHT}@120\", position = \"auto\", scale = ${SCALE} })" > /dev/null 2>&1 && hyprctl eval 'hl.config({ misc = { vrr = 2 } })' > /dev/null 2>&1; then
        notify-send "Screen Mode" "120Hz VRR (${OUTPUT})"
    else
        notify-send -u critical "Screen Mode" "VRR mode switch not supported on ${OUTPUT}"
    fi
else
    # Currently VRR is active. Switch to 60Hz Locked.
    if hyprctl eval "hl.monitor({ output = \"${OUTPUT}\", mode = \"${WIDTH}x${HEIGHT}@60\", position = \"auto\", scale = ${SCALE} })" > /dev/null 2>&1 && hyprctl eval 'hl.config({ misc = { vrr = 0 } })' > /dev/null 2>&1; then
        notify-send "Screen Mode" "60Hz Locked (${OUTPUT})"
    else
        notify-send -u critical "Screen Mode" "60Hz mode switch not supported on ${OUTPUT}"
    fi
fi
