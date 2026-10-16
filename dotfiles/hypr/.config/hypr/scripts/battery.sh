#!/usr/bin/env bash

# Detect battery device
BAT_DIR=""
for b in /sys/class/power_supply/BAT*; do
  if [[ -d "$b" && -f "$b/capacity" && -f "$b/status" ]]; then
    BAT_DIR="$b"
    break
  fi
done

# If no battery found (e.g. desktop PC), exit cleanly
if [[ -z "$BAT_DIR" ]]; then
  exit 0
fi

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp/hyprvibe-$UID}"
mkdir -p "$STATE_DIR"

SOUND_FILE="/usr/share/sounds/freedesktop/stereo/suspend-error.oga"

play_alert() {
  if [[ -f "$SOUND_FILE" ]] && command -v pw-play >/dev/null 2>&1; then
    pw-play "$SOUND_FILE" &
  fi
}

while true; do
  bat_lvl=$(cat "$BAT_DIR/capacity" 2>/dev/null || echo 100)
  bat_status=$(cat "$BAT_DIR/status" 2>/dev/null || echo "Unknown")

  if [[ "$bat_status" == "Discharging" ]]; then
    # Critical Battery at 15% or below
    if (( bat_lvl <= 15 )) && [[ ! -f "$STATE_DIR/bat_crit_sent" ]]; then
      play_alert
      notify-send -u critical -h string:x-canonical-private-synchronous:battery "  Battery Level is Critical (${bat_lvl}%)!"
      touch "$STATE_DIR/bat_crit_sent"

    # Low Battery at 30% or below (above 15%)
    elif (( bat_lvl <= 30 && bat_lvl > 15 )) && [[ ! -f "$STATE_DIR/bat_low_sent" ]]; then
      play_alert
      notify-send -u critical -h string:x-canonical-private-synchronous:battery "  Battery Level is Low (${bat_lvl}%)"
      touch "$STATE_DIR/bat_low_sent"
    fi
  else
    # Reset flags when charging
    rm -f "$STATE_DIR/bat_crit_sent" "$STATE_DIR/bat_low_sent"
  fi

  sleep 30
done
