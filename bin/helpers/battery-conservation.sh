#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Title: Battery Conservation
# Description: Helper script to toggle laptop battery conservation charging cap
# ==============================================================================

HELPER_TITLE="Battery Conservation"
HELPER_ICON="󰂄"
HELPER_ORDER=25

# ------------------------------------------------------------------------------
# Floating Window Spawn Logic (40% screen width x 40% height, centered)
# ------------------------------------------------------------------------------
IS_INNER=false
for a in "$@"; do
    [[ "$a" == "--inner" || "$a" == "--headless" ]] && IS_INNER=true
done

if [[ "$IS_INNER" == "false" ]]; then
    SCRIPT_FILE=$(readlink -f "$0")

    MON_INFO=$(hyprctl monitors -j 2>/dev/null || true)
    WIDTH=$(echo "$MON_INFO" | jq -r '.[] | select(.focused == true) | .width // empty' 2>/dev/null || true)
    if [[ -z "$WIDTH" ]]; then
        WIDTH=$(echo "$MON_INFO" | jq -r '.[0].width // 1920' 2>/dev/null || true)
        HEIGHT=$(echo "$MON_INFO" | jq -r '.[0].height // 1080' 2>/dev/null || true)
        SCALE=$(echo "$MON_INFO" | jq -r '.[0].scale // 1.0' 2>/dev/null || true)
    else
        HEIGHT=$(echo "$MON_INFO" | jq -r '.[] | select(.focused == true) | .height // 1080' 2>/dev/null || true)
        SCALE=$(echo "$MON_INFO" | jq -r '.[] | select(.focused == true) | .scale // 1.0' 2>/dev/null || true)
    fi

    TARGET_W=$(awk -v w="$WIDTH" -v s="$SCALE" 'BEGIN { printf "%d", (w / s) * 0.40 }')
    TARGET_H=$(awk -v h="$HEIGHT" -v s="$SCALE" 'BEGIN { printf "%d", (h / s) * 0.40 }')
    [[ "$TARGET_W" -lt 600 ]] && TARGET_W=600
    [[ "$TARGET_H" -lt 380 ]] && TARGET_H=380

    if command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1; then
        hyprctl eval "hl.window_rule({ match = { class = 'battery-conservation' }, float = true, center = true, size = '${TARGET_W} ${TARGET_H}' })" >/dev/null 2>&1 || true
        hyprctl eval "hl.exec_cmd('foot -a battery-conservation -T \"${HELPER_TITLE}\" -w ${TARGET_W}x${TARGET_H} bash \"${SCRIPT_FILE}\" --inner \"$@\"')" >/dev/null 2>&1 || true
        exit 0
    fi
fi

# ------------------------------------------------------------------------------
# Hardware Path Discovery
# ------------------------------------------------------------------------------
find_conservation_path() {
    local candidate
    for candidate in \
        "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode" \
        "/sys/devices/platform/ideapad_acpi/VPC2004:00/conservation_mode"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    find /sys/devices/ -name "conservation_mode" 2>/dev/null | head -n 1
}

CONSERVATION_PATH="$(find_conservation_path)"

# ------------------------------------------------------------------------------
# Title Display (Clean left-aligned text, no wrapping)
# ------------------------------------------------------------------------------
print_title() {
    echo ""
    echo "  ${HELPER_ICON}  ${HELPER_TITLE}"
    echo ""
}

# ------------------------------------------------------------------------------
# Headless / Batch Support (CLI & Test friendly)
# ------------------------------------------------------------------------------
for ((i=1; i<=$#; i++)); do
    arg="${!i}"
    case "$arg" in
        --status)
            if [[ -z "$CONSERVATION_PATH" || ! -f "$CONSERVATION_PATH" ]]; then
                echo "unsupported"
                exit 0
            fi
            cat "$CONSERVATION_PATH" 2>/dev/null | tr -d '[:space:]'
            echo ""
            exit 0
            ;;
        --set)
            next_idx=$((i+1))
            val="${!next_idx:-}"
            if [[ "$val" != "0" && "$val" != "1" ]]; then
                echo "Error: --set requires 0 or 1" >&2
                exit 1
            fi
            if [[ -z "$CONSERVATION_PATH" || ! -f "$CONSERVATION_PATH" ]]; then
                echo "Error: Conservation mode unsupported" >&2
                exit 1
            fi
            echo "$val" | sudo tee "$CONSERVATION_PATH" >/dev/null
            exit 0
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Interactive UI
# ------------------------------------------------------------------------------
clear
print_title

if [[ -z "$CONSERVATION_PATH" || ! -f "$CONSERVATION_PATH" ]]; then
    echo "  ❌ Conservation Mode not supported or ACPI driver not loaded."
    echo ""
    notify-send -u normal -a "${HELPER_TITLE}" "${HELPER_TITLE}" "Conservation mode not supported on this hardware" 2>/dev/null || true
    read -rp "  Press Enter to exit..." _
    exit 1
fi

current=$(cat "$CONSERVATION_PATH" 2>/dev/null | tr -d '[:space:]')

echo "  Status:"
if [[ "$current" == "1" ]]; then
    echo "    • Current:  󰂄 Conservation Mode (Active)"
    echo "    • Limit:    Charging capped at 60% (protects battery life)"
elif [[ "$current" == "0" ]]; then
    echo "    • Current:  ⚡ Normal Mode (Active)"
    echo "    • Limit:    Full 100% charge (maximum portable runtime)"
else
    echo "    • Current:  ❓ Unknown State ('$current')"
fi

echo ""
echo "  Options:"
echo "    [1]  󰂄  Enable Conservation Mode (60% cap)"
echo "    [2]  ⚡  Enable Normal Mode (100% full charge)"
echo "    [q]  Exit"
echo ""

read -rp "  Select an option [1/2/q]: " choice

case "$choice" in
    1)
        if echo 1 | sudo tee "$CONSERVATION_PATH" > /dev/null 2>&1; then
            echo ""
            echo "  ✅ Switched to Conservation Mode"
            notify-send -a "${HELPER_TITLE}" "${HELPER_TITLE}" "Switched to Conservation Mode (60% cap)" 2>/dev/null || true
        else
            echo ""
            echo "  ❌ Failed to write conservation mode (sudo failed or permission denied)"
        fi
        ;;
    2)
        if echo 0 | sudo tee "$CONSERVATION_PATH" > /dev/null 2>&1; then
            echo ""
            echo "  ✅ Switched to Normal Mode"
            notify-send -a "${HELPER_TITLE}" "${HELPER_TITLE}" "Switched to Normal Mode (100% charge)" 2>/dev/null || true
        else
            echo ""
            echo "  ❌ Failed to write conservation mode (sudo failed or permission denied)"
        fi
        ;;
    [qQ]|"")
        echo ""
        echo "  Exiting without changes."
        ;;
    *)
        echo ""
        echo "  ❌ Invalid choice."
        ;;
esac

echo ""
sleep 1
