#!/usr/bin/env bash

# ---- CONFIG ----
WALL_DIR="$HOME/Pictures/Wallpapers"
INTERVAL=45
MODE="fill" # fill | fit | stretch | center | tile

if ! command -v swaybg >/dev/null 2>&1; then
  exit 0
fi

CURRENT_PID=""
SLEEP_PID=""
LAST_WALL=""
FORCE_RELOAD=0

# ---- PICK RANDOM WALLPAPER (NO CONSECUTIVE DUPLICATES) ----
pick_wallpaper() {
  local wall_count="$1"
  local chosen=""
  if [ "$wall_count" -gt 1 ] && [ -n "$LAST_WALL" ]; then
    chosen="$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) ! -name "$(basename "$LAST_WALL")" 2>/dev/null | shuf -n 1)"
  fi
  if [ -z "$chosen" ]; then
    chosen="$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1)"
  fi
  echo "$chosen"
}

change_wallpaper() {
  if [ ! -d "$WALL_DIR" ]; then
    return
  fi

  local wall_count
  wall_count="$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | wc -l)"

  # Zero wallpapers — nothing to show
  if [ "$wall_count" -eq 0 ]; then
    return
  fi

  if [ "$wall_count" -le 1 ] && [ -n "$CURRENT_PID" ] && [ "$FORCE_RELOAD" -ne 1 ]; then
    # Only one wallpaper and already displaying it — just wait
    return
  fi

  local wall
  wall="$(pick_wallpaper "$wall_count")"
  if [ -z "$wall" ]; then
    return
  fi

  # Start new swaybg first
  swaybg -i "$wall" -m "$MODE" &
  local new_pid=$!

  # Allow swaybg to map before killing the old one
  sleep 0.3

  # Kill previous swaybg instance (prevents leaks)
  if [ -n "$CURRENT_PID" ]; then
    kill "$CURRENT_PID" 2>/dev/null || true
  fi

  CURRENT_PID="$new_pid"
  LAST_WALL="$wall"
  FORCE_RELOAD=0
}

on_usr1() {
  # Terminate current sleep so interval resets immediately
  FORCE_RELOAD=1
  if [ -n "$SLEEP_PID" ]; then
    kill "$SLEEP_PID" 2>/dev/null || true
  fi
}

cleanup() {
  if [ -n "$CURRENT_PID" ]; then
    kill "$CURRENT_PID" 2>/dev/null || true
  fi
  exit 0
}

trap 'cleanup' SIGINT SIGTERM
trap 'on_usr1' SIGUSR1

while true; do
  change_wallpaper
  sleep "$INTERVAL" &
  SLEEP_PID=$!
  wait "$SLEEP_PID" 2>/dev/null || true
  SLEEP_PID=""
done
