#!/usr/bin/env bash

# Fetch current vrr state (0 = off, 1 = on, 2 = fullscreen)
# Using hyprctl getoption to determine current state
STATE=$(hyprctl getoption misc.vrr -j | grep '"int": 0')

if [ -n "$STATE" ]; then
    # Currently 0 (off, 60Hz locked). Switch to 120Hz VRR.
    if hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "auto", scale = 1.8 })' > /dev/null 2>&1 && hyprctl eval 'hl.config({ misc = { vrr = 2 } })' > /dev/null 2>&1; then
        notify-send "Screen Mode" "120Hz VRR"
    else
        notify-send -u critical "Screen Mode" "Failed to switch to 120Hz VRR"
    fi
else
    # Currently VRR is active. Switch to 60Hz Locked.
    if hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "2880x1800@60", position = "auto", scale = 1.8 })' > /dev/null 2>&1 && hyprctl eval 'hl.config({ misc = { vrr = 0 } })' > /dev/null 2>&1; then
        notify-send "Screen Mode" "60Hz Locked"
    else
        notify-send -u critical "Screen Mode" "Failed to switch to 60Hz Locked"
    fi
fi
