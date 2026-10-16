#!/usr/bin/env bash

# ---- CONFIG ----
WALL_DIR="${WALL_DIR:-$HOME/Pictures/Wallpapers}"
INTERVAL=45
MODE="fill" # fill | fit | stretch | center | tile
STATE_FILE="$HOME/.local/state/hyprvibe/current_wallpaper"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/hyprvibe-wallpaper-changer.lock"

if ! command -v swaybg >/dev/null 2>&1; then
  exit 0
fi

# Ensure single running instance
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  exit 0
fi

mkdir -p "$(dirname "$STATE_FILE")"

CURRENT_PID=""
SLEEP_PID=""
LAST_WALL=""
DECK=()

# Detect currently displayed wallpaper on startup
if [[ -f "$STATE_FILE" ]]; then
  LAST_WALL="$(cat "$STATE_FILE" 2>/dev/null)"
fi
if [[ -z "$LAST_WALL" ]]; then
  LAST_WALL="$(pgrep -a swaybg 2>/dev/null | grep -oP '(?<=-i )\S+' | head -n 1)"
fi

# Adopt running swaybg PID to prevent orphaned processes
CURRENT_PID="$(pgrep -o swaybg 2>/dev/null || true)"

refill_deck() {
  readarray -d '' -t DECK < <(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0 2>/dev/null | shuf -z)

  local count=${#DECK[@]}
  if (( count == 0 )); then
    return
  fi

  # Prevent repeating the last wallpaper across cycle boundaries
  if (( count > 1 )) && [[ -n "$LAST_WALL" && "${DECK[0]}" == "$LAST_WALL" ]]; then
    local swap_idx=$(( (RANDOM % (count - 1)) + 1 ))
    local tmp="${DECK[0]}"
    DECK[0]="${DECK[swap_idx]}"
    DECK[swap_idx]="$tmp"
  fi
}

change_wallpaper() {
  if [[ ! -d "$WALL_DIR" ]]; then
    return
  fi

  # Refill and shuffle deck when empty
  if (( ${#DECK[@]} == 0 )); then
    refill_deck
  fi

  local count=${#DECK[@]}
  if (( count == 0 )); then
    return
  fi

  # If only 1 wallpaper and already showing it, avoid re-rendering
  if (( count == 1 )) && [[ "${DECK[0]}" == "$LAST_WALL" ]] && [[ -n "$CURRENT_PID" ]] && kill -0 "$CURRENT_PID" 2>/dev/null; then
    return
  fi

  local wall="${DECK[0]}"
  DECK=("${DECK[@]:1}")

  # Spawn new swaybg first (close fd 200 so children don't inherit lock)
  swaybg -i "$wall" -m "$MODE" 200>&- >/dev/null 2>&1 &
  local new_pid=$!

  # Allow Wayland compositor to map surface before terminating old instance
  sleep 0.5

  # Kill previous swaybg instance
  if [[ -n "$CURRENT_PID" && "$CURRENT_PID" != "$new_pid" ]]; then
    kill "$CURRENT_PID" 2>/dev/null || true
  fi

  CURRENT_PID="$new_pid"
  LAST_WALL="$wall"
  echo "$wall" > "$STATE_FILE" 2>/dev/null || true
}

on_usr1() {
  # Terminate current sleep so interval resets immediately, flush deck to re-read wall dir
  DECK=()
  if [[ -n "$SLEEP_PID" ]]; then
    kill "$SLEEP_PID" 2>/dev/null || true
  fi
}

cleanup() {
  if [[ -n "$CURRENT_PID" ]]; then
    kill "$CURRENT_PID" 2>/dev/null || true
  fi
  exit 0
}

trap 'cleanup' SIGINT SIGTERM
trap '' SIGHUP
trap 'on_usr1' SIGUSR1

while true; do
  change_wallpaper
  sleep "$INTERVAL" 200>&- &
  SLEEP_PID=$!
  wait "$SLEEP_PID" 2>/dev/null || true
  SLEEP_PID=""
done
