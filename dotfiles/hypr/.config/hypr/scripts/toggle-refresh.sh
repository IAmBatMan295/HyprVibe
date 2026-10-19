#!/usr/bin/env bash

# Fetch active monitor info dynamically
MON_INFO=$(hyprctl monitors -j 2>/dev/null || true)
if [[ -z "$MON_INFO" || "$MON_INFO" == "[]" ]]; then
    notify-send -u critical "Screen Mode" "No active monitor found / Not supported on this display"
    exit 1
fi

# Single-pass dynamic geometry parsing
read -r OUTPUT WIDTH HEIGHT SCALE < <(echo "$MON_INFO" | jq -r '.[0] | "\(.name // "") \(.width // "") \(.height // "") \(.scale // 1.0)"' 2>/dev/null || echo "")

if [[ -z "$OUTPUT" || -z "$WIDTH" || -z "$HEIGHT" ]]; then
    notify-send -u critical "Screen Mode" "Could not detect active monitor resolution"
    exit 1
fi

# Detect highest available refresh rate for native resolution in a single JQ pass
MAX_RATE=$(echo "$MON_INFO" | jq -r '
    [.[0] as $m | ($m.availableModes[]? | select(startswith("\($m.width)x\($m.height)@")) | ltrimstr("\($m.width)x\($m.height)@") | rtrimstr("Hz") | split(".")[0] | tonumber)] | max // 120
' 2>/dev/null || echo "120")
[[ -z "$MAX_RATE" ]] && MAX_RATE="120"

if (( MAX_RATE <= 60 )); then
    notify-send "Screen Mode" "Display only supports ${MAX_RATE}Hz. High refresh rate toggle not applicable."
    exit 0
fi

# Fetch current vrr state (0 = off, 1 = on, 2 = fullscreen)
STATE=$(hyprctl getoption misc.vrr -j 2>/dev/null | grep '"int": 0' || true)

if [ -n "$STATE" ]; then
    # Currently 0 (off, 60Hz locked). Switch to MAX_RATE VRR.
    if hyprctl eval "hl.monitor({ output = \"${OUTPUT}\", mode = \"${WIDTH}x${HEIGHT}@${MAX_RATE}\", position = \"auto\", scale = ${SCALE} })" > /dev/null 2>&1 && hyprctl eval 'hl.config({ misc = { vrr = 2 } })' > /dev/null 2>&1; then
        notify-send "Screen Mode" "${MAX_RATE}Hz VRR (${OUTPUT})"
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
