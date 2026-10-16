#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Title: Wallpaper Theming
# Description: Interactive wallpaper color recoloring using lutgen and Hyprland
# ==============================================================================

HELPER_TITLE="Wallpaper Theming"
HELPER_ICON=""
HELPER_ORDER=10

PALETTES=(
    "catppuccin-mocha|Catppuccin Mocha"
    "tokyo-night-dark|Tokyo Night Dark"
    "everforest-dark-medium|Everforest Dark"
    "gruvbox-dark|Gruvbox Dark"
    "grayscale-dark|Monochrome"
)

# ------------------------------------------------------------------------------
# Safe Filename Generator (Non-destructive, never overwrites original)
# Automatically adds theme suffix and (copy) / (copy N) if file already exists
# ------------------------------------------------------------------------------
get_safe_target_path() {
    local dest_dir="$1"
    local orig_file="$2"
    local palette="$3"

    local base
    base=$(basename "$orig_file")
    local name="${base%.*}"
    local ext="${base##*.}"

    local target="${dest_dir}/${name}_${palette}.${ext}"
    local count=1

    while [[ -e "$target" ]]; do
        if [[ $count -eq 1 ]]; then
            target="${dest_dir}/${name}_${palette} (copy).${ext}"
        else
            target="${dest_dir}/${name}_${palette} (copy ${count}).${ext}"
        fi
        ((count++)) || true
    done
    printf '%s\n' "$target"
}

# ------------------------------------------------------------------------------
# Headless / Batch processing support (for tests & scripting)
# ------------------------------------------------------------------------------
if [[ "${1:-}" == "--headless" ]]; then
    shift
    HEADLESS_PALETTE_INDEX=""
    HEADLESS_FILES=()
    HEADLESS_OUT_DIR=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --palette)
                HEADLESS_PALETTE_INDEX="$2"
                shift 2
                ;;
            --files)
                shift
                while [[ $# -gt 0 && "$1" != --* ]]; do
                    HEADLESS_FILES+=("$1")
                    shift
                done
                ;;
            --out-dir)
                HEADLESS_OUT_DIR="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    IDX=$((HEADLESS_PALETTE_INDEX - 1))
    PALETTE_DATA="${PALETTES[$IDX]}"
    PALETTE_SLUG="${PALETTE_DATA%%|*}"
    PALETTE_NAME="${PALETTE_DATA##*|}"

    COUNT=0
    for f in "${HEADLESS_FILES[@]}"; do
        if [[ -f "$f" ]]; then
            target_path=$(get_safe_target_path "$HEADLESS_OUT_DIR" "$f" "$PALETTE_SLUG")
            lutgen apply -p "$PALETTE_SLUG" -l 12 "$f" -o "$target_path" >/dev/null 2>&1
            ((COUNT++)) || true
        fi
    done

    command -v notify-send >/dev/null 2>&1 && notify-send -a "${HELPER_TITLE}" "${HELPER_TITLE}" "Successfully themed $COUNT wallpaper(s) ($PALETTE_NAME)" || true
    exit 0
fi

# ------------------------------------------------------------------------------
# Floating Window Spawn Logic
# ------------------------------------------------------------------------------
# If not already running inside our dedicated floating window, calculate active
# screen resolution (40% width x 40% height) and launch foot via hyprctl eval (hl. API)
if [[ "${1:-}" != "--inner" ]]; then
    SCRIPT_FILE=$(readlink -f "$0")

    # Fetch active/focused monitor resolution dynamically
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

    # Dynamic 40% scaling (accounting for display scale)
    TARGET_W=$(awk -v w="$WIDTH" -v s="$SCALE" 'BEGIN { printf "%d", (w / s) * 0.40 }')
    TARGET_H=$(awk -v h="$HEIGHT" -v s="$SCALE" 'BEGIN { printf "%d", (h / s) * 0.40 }')
    [[ "$TARGET_W" -lt 600 ]] && TARGET_W=600
    [[ "$TARGET_H" -lt 380 ]] && TARGET_H=380

    # Register rule and launch foot via Hyprland Lua eval API
    if command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1; then
        hyprctl eval "hl.window_rule({ match = { class = 'wallpaper-theming' }, float = true, center = true, size = '${TARGET_W} ${TARGET_H}' })" >/dev/null 2>&1 || true
        hyprctl eval "hl.exec_cmd('foot -a wallpaper-theming -T \"${HELPER_TITLE}\" -w ${TARGET_W}x${TARGET_H} bash \"${SCRIPT_FILE}\" --inner')" >/dev/null 2>&1 || true
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

# ------------------------------------------------------------------------------
# Interactive Menu
# ------------------------------------------------------------------------------
clear
print_title
echo "  Select Palette:"
for i in "${!PALETTES[@]}"; do
    num=$((i + 1))
    name="${PALETTES[$i]##*|}"
    echo "    $num) $name"
done
echo "    q) Quit"
echo ""

read -rp "  Choice [1-${#PALETTES[@]}]: " choice

if [[ "$choice" =~ ^[qQ]$ ]]; then
    echo "Exiting."
    exit 0
fi

if ! [[ "$choice" =~ ^[1-5]$ ]]; then
    echo "Invalid choice. Exiting."
    exit 1
fi

SELECTED_IDX=$((choice - 1))
SELECTED_PALETTE="${PALETTES[$SELECTED_IDX]%%|*}"
SELECTED_NAME="${PALETTES[$SELECTED_IDX]##*|}"

echo ""
echo "  Selected: $SELECTED_NAME ($SELECTED_PALETTE)"
echo "  Opening file picker for input wallpapers..."

# ------------------------------------------------------------------------------
# File Picker (Zenity Multi-file)
# ------------------------------------------------------------------------------
RAW_FILES=$(zenity --file-selection --multiple --separator="|" \
    --title="Wallpaper Theming - Select Wallpapers" \
    --file-filter="Images (*.png, *.jpg, *.jpeg, *.webp, *.avif) | *.png *.jpg *.jpeg *.webp *.avif *.PNG *.JPG *.JPEG *.WEBP *.AVIF" \
    2>/dev/null || true)

if [[ -z "$RAW_FILES" ]]; then
    echo "No files selected. Cancelled."
    exit 0
fi

IFS="|" read -r -a INPUT_FILES <<< "$RAW_FILES"
echo "  Selected ${#INPUT_FILES[@]} file(s)."
echo ""
echo "  Opening directory picker for destination..."

# ------------------------------------------------------------------------------
# Destination Directory Picker (Zenity Directory)
# ------------------------------------------------------------------------------
DEST_DIR=$(zenity --file-selection --directory \
    --title="Wallpaper Theming - Select Target Directory" \
    --filename="$HOME/Pictures/Wallpapers/" \
    2>/dev/null || true)

if [[ -z "$DEST_DIR" ]]; then
    echo "No destination directory selected. Cancelled."
    exit 0
fi

mkdir -p "$DEST_DIR"

# ------------------------------------------------------------------------------
# Process with lutgen (Zenity GUI progress bar, no log output in dialog)
# ------------------------------------------------------------------------------
SUCCESS_COUNT=0
TOTAL_FILES=${#INPUT_FILES[@]}
CURRENT=0

clear
print_title
echo "  Theming $TOTAL_FILES wallpaper(s) with $SELECTED_NAME..."
echo "  Follow progress in the dialog window."
echo ""

(
    for img in "${INPUT_FILES[@]}"; do
        if [[ ! -f "$img" ]]; then
            continue
        fi
        ((CURRENT++)) || true
        pct=$(( CURRENT * 100 / TOTAL_FILES ))
        echo "$pct"
        echo "# Theming wallpaper $CURRENT of $TOTAL_FILES..."

        target_file=$(get_safe_target_path "$DEST_DIR" "$img" "$SELECTED_PALETTE")
        if lutgen apply -p "$SELECTED_PALETTE" -l 12 "$img" -o "$target_file" 2>/dev/null; then
            ((SUCCESS_COUNT++)) || true
        fi
    done
) | zenity --progress \
    --title="Wallpaper Theming" \
    --text="Theming wallpapers..." \
    --percentage=0 \
    --auto-close \
    --no-cancel 2>/dev/null || true

# Notify via notification daemon (Mako)
notify-send -a "Wallpaper Theming" "Wallpaper Theming" "Successfully themed $SUCCESS_COUNT wallpaper(s) with $SELECTED_NAME" 2>/dev/null || true
exit 0
