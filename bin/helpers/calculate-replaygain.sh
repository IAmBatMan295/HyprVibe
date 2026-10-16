#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Title: Calculate ReplayGain
# Description: Helper script to calculate and apply ReplayGain tags via rsgain
# ==============================================================================

HELPER_TITLE="Calculate ReplayGain"
HELPER_ICON="󰎈"
HELPER_ORDER=40

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
        hyprctl eval "hl.window_rule({ match = { class = 'calculate-replaygain' }, float = true, center = true, size = '${TARGET_W} ${TARGET_H}' })" >/dev/null 2>&1 || true
        hyprctl eval "hl.exec_cmd('foot -a calculate-replaygain -T \"${HELPER_TITLE}\" -w ${TARGET_W}x${TARGET_H} bash \"${SCRIPT_FILE}\" --inner \"$@\"')" >/dev/null 2>&1 || true
        exit 0
    fi
fi

# ------------------------------------------------------------------------------
# Dependency Verification
# ------------------------------------------------------------------------------
if ! command -v rsgain >/dev/null 2>&1; then
    echo "  ❌ Error: 'rsgain' is not installed or not in PATH." >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "${HELPER_TITLE}" "Error: rsgain is not installed" -u critical
    fi
    exit 1
fi

DEFAULT_DIR="${HOME}/Music/music"
[[ ! -d "$DEFAULT_DIR" ]] && DEFAULT_DIR="${HOME}/Music"
[[ ! -d "$DEFAULT_DIR" ]] && DEFAULT_DIR="${HOME}"

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
HEADLESS=false
DRY_RUN=false
PRESET_SKIP=""
TARGET_DIR=""

for arg in "$@"; do
    case "$arg" in
        --headless) HEADLESS=true ;;
        --dry-run) DRY_RUN=true ;;
        --skip) PRESET_SKIP="y" ;;
        --no-skip) PRESET_SKIP="n" ;;
        --dir=*) TARGET_DIR="${arg#*=}" ;;
        --inner) ;;
        *)
            if [[ -d "$arg" && -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$arg"
            fi
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Title Display (Clean left-aligned text, no wrapping, matching helpers standard)
# ------------------------------------------------------------------------------
print_title() {
    echo ""
    echo "  ${HELPER_ICON}  ${HELPER_TITLE}"
    echo ""
}

# ------------------------------------------------------------------------------
# Non-Interactive / Headless / Dry-Run Mode
# ------------------------------------------------------------------------------
if [[ "$HEADLESS" == "true" ]]; then
    if [[ -z "$TARGET_DIR" ]]; then
        TARGET_DIR="$DEFAULT_DIR"
    fi

    SKIP_ARGS=()
    if [[ "$PRESET_SKIP" == "y" || -z "$PRESET_SKIP" ]]; then
        SKIP_ARGS=("-S")
    fi

    CMD=(rsgain easy -m MAX -p no_album "${SKIP_ARGS[@]}" "$TARGET_DIR")
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "${CMD[*]}"
        exit 0
    fi

    "${CMD[@]}"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "${HELPER_TITLE}" "ReplayGain tags applied to $(basename "$TARGET_DIR")" -i audio-volume-high
    fi
    exit 0
fi

# ------------------------------------------------------------------------------
# Interactive Execution
# ------------------------------------------------------------------------------
clear
print_title

echo "  Skip files with existing ReplayGain metadata?"
echo ""
read -r -p "  Proceed? [Y/n]: " choice

if [[ "$choice" =~ ^[qQ]$ ]]; then
    echo ""
    echo "  Exiting."
    exit 0
fi

SKIP_ARGS=()
SKIP_DESC="Re-calculating all files"
case "${choice,,}" in
    n|no)
        SKIP_ARGS=()
        SKIP_DESC="Re-calculating all files"
        ;;
    *)
        SKIP_ARGS=("-S")
        SKIP_DESC="Skipping files with existing metadata (-S)"
        ;;
esac

# Directory selection via Zenity if not passed via CLI
if [[ -z "$TARGET_DIR" ]]; then
    echo ""
    echo "  Opening directory picker for music folder..."
    if command -v zenity >/dev/null 2>&1; then
        TARGET_DIR=$(zenity --file-selection --directory \
            --title="${HELPER_TITLE} - Select Music Directory" \
            --filename="${DEFAULT_DIR}/" \
            2>/dev/null || true)
    fi

    if [[ -z "$TARGET_DIR" ]]; then
        if command -v zenity >/dev/null 2>&1; then
            echo ""
            echo "  No directory selected. Cancelled."
            exit 0
        else
            echo ""
            read -r -e -p "  Enter music directory [default: ${DEFAULT_DIR}]: " manual_dir
            TARGET_DIR="${manual_dir:-$DEFAULT_DIR}"
        fi
    fi
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo ""
    echo "  ❌ Error: Directory not found: $TARGET_DIR" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "${HELPER_TITLE}" "Error: Directory not found" -u critical
    fi
    exit 1
fi

echo ""
echo "  Target: $TARGET_DIR"
echo "  Mode:   $SKIP_DESC"
echo ""
echo "  Running rsgain..."
echo ""

rsgain easy -m MAX -p no_album "${SKIP_ARGS[@]}" "$TARGET_DIR"

if command -v notify-send >/dev/null 2>&1; then
    notify-send "${HELPER_TITLE}" "ReplayGain tags applied to $(basename "$TARGET_DIR")" -i audio-volume-high
fi

echo ""
echo "  ✅ ReplayGain tags processed successfully."
echo ""
read -r -p "  Press Enter to exit..." _
