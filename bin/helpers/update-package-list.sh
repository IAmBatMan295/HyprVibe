#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Title: Update Package List
# Description: Helper script to snapshot pacman and yay installed packages
# ==============================================================================

HELPER_TITLE="Update Package List"
HELPER_ICON=""
HELPER_ORDER=20

# ------------------------------------------------------------------------------
# Floating Window Spawn Logic (40% screen width x 40% height, centered)
# ------------------------------------------------------------------------------
if [[ "${1:-}" != "--inner" && "${1:-}" != "--headless" ]]; then
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
        hyprctl eval "hl.window_rule({ match = { class = 'update-package-list' }, float = true, center = true, size = '${TARGET_W} ${TARGET_H}' })" >/dev/null 2>&1 || true
        hyprctl eval "hl.exec_cmd('foot -a update-package-list -T \"${HELPER_TITLE}\" -w ${TARGET_W}x${TARGET_H} bash \"${SCRIPT_FILE}\" --inner \"$@\"')" >/dev/null 2>&1 || true
        exit 0
    fi
fi

# ------------------------------------------------------------------------------
# Title Display (Clean left-aligned text, no wrapping)
# ------------------------------------------------------------------------------
print_title() {
    echo ""
    echo "  ${HELPER_ICON}  ${HELPER_TITLE}"
    echo ""
}

clear
print_title

# Paths
REAL_SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
ROOT_DIR="$(cd -- "$(dirname -- "${REAL_SCRIPT}")/../.." && pwd)"
PACMAN_TXT="${ROOT_DIR}/packages/pacman.txt"
YAY_TXT="${ROOT_DIR}/packages/yay.txt"

# Non-interactive / headless check
AUTO_YES=false
for arg in "$@"; do
    if [[ "$arg" == "--yes" || "$arg" == "-y" || "$arg" == "--headless" ]]; then
        AUTO_YES=true
    fi
done

if [[ "$AUTO_YES" != "true" ]]; then
    echo "  Update pacman.txt & yay.txt in HyprVibe packages/?"
    echo ""
    read -rp "  Proceed? [Y/n]: " response
    response="${response:-Y}"
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo ""
        echo "  Aborted."
        echo ""
        sleep 1
        exit 0
    fi
    echo ""
fi

echo "  Running pacman and yay queries..."

if pacman -Qneq > "$PACMAN_TXT" && pacman -Qmeq > "$YAY_TXT"; then
    PAC_COUNT=$(wc -l < "$PACMAN_TXT")
    YAY_COUNT=$(wc -l < "$YAY_TXT")
    echo ""
    echo "  ✅ Successfully updated package lists:"
    echo "     - pacman.txt: $PAC_COUNT packages"
    echo "     - yay.txt:    $YAY_COUNT packages"
    echo ""
    notify-send -a "${HELPER_TITLE}" "${HELPER_TITLE}" "Successfully updated pacman ($PAC_COUNT) & yay ($YAY_COUNT) lists" 2>/dev/null || true
else
    echo ""
    echo "  ❌ Failed to update package lists."
    echo ""
    notify-send -u critical -a "${HELPER_TITLE}" "${HELPER_TITLE}" "Failed to update package lists" 2>/dev/null || true
fi

if [[ "$AUTO_YES" != "true" ]]; then
    read -rp "  Press Enter to exit..."
fi
