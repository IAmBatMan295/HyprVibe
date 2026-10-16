#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Title: Rename Theme Wallpapers
# Description: Helper script to standardize theme wallpapers to <theme>-<index>.<ext>
# ==============================================================================

HELPER_TITLE="Rename Theme Wallpapers"
HELPER_ICON=""
HELPER_ORDER=30

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
        hyprctl eval "hl.window_rule({ match = { class = 'rename-theme-wallpapers' }, float = true, center = true, size = '${TARGET_W} ${TARGET_H}' })" >/dev/null 2>&1 || true
        hyprctl eval "hl.exec_cmd('foot -a rename-theme-wallpapers -T \"${HELPER_TITLE}\" -w ${TARGET_W}x${TARGET_H} bash \"${SCRIPT_FILE}\" --inner \"$@\"')" >/dev/null 2>&1 || true
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
THEMES_DIR="${ROOT_DIR}/themes"

if [[ ! -d "$THEMES_DIR" ]]; then
    echo "  ❌ Error: themes directory not found at $THEMES_DIR" >&2
    exit 1
fi

# Non-interactive / headless check
AUTO_YES=false
for arg in "$@"; do
    if [[ "$arg" == "--yes" || "$arg" == "-y" || "$arg" == "--headless" ]]; then
        AUTO_YES=true
    fi
done

if [[ "$AUTO_YES" != "true" ]]; then
    echo "  Standardize theme wallpapers to <theme>-<index>.<ext>?"
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

echo "  Standardizing wallpapers in themes/ backgrounds..."
echo ""

TOTAL_RENAMED=0
python3 - "$THEMES_DIR" << 'EOF'
import os
import sys

themes_dir = sys.argv[1]
if not os.path.isdir(themes_dir):
    sys.exit(f"Directory not found: {themes_dir}")

total = 0
for theme in sorted(os.listdir(themes_dir)):
    bg_dir = os.path.join(themes_dir, theme, "backgrounds")
    if not os.path.isdir(bg_dir):
        continue

    files = sorted([
        f for f in os.listdir(bg_dir)
        if os.path.isfile(os.path.join(bg_dir, f)) and not f.startswith(".")
    ])

    if not files:
        continue

    print(f"  [{theme}] Renaming {len(files)} wallpaper(s)...")

    # Phase 1: Temporary names to prevent collision
    temp_files = []
    for i, fname in enumerate(files, 1):
        ext = os.path.splitext(fname)[1]
        temp_name = f"__tmp_renaming_{theme}_{i}{ext}"
        src = os.path.join(bg_dir, fname)
        dst = os.path.join(bg_dir, temp_name)
        os.rename(src, dst)
        temp_files.append((dst, ext))

    # Phase 2: Standardized names
    for i, (temp_path, ext) in enumerate(temp_files, 1):
        final_name = f"{theme}-{i}{ext}"
        final_path = os.path.join(bg_dir, final_name)
        os.rename(temp_path, final_path)
        total += 1

print(f"\n  ✅ All {total} theme wallpapers standardized successfully.")
EOF

notify-send -a "${HELPER_TITLE}" "${HELPER_TITLE}" "Successfully standardized theme wallpapers" 2>/dev/null || true

echo ""
if [[ "$AUTO_YES" != "true" ]]; then
    read -rp "  Press Enter to exit..."
fi
