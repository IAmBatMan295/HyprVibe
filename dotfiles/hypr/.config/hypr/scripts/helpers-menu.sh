#!/usr/bin/env bash
set -euo pipefail

# Resolve real script location by dereferencing symlink (Stow / symlink design)
REAL_SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
REAL_DIR="$(cd -- "$(dirname -- "${REAL_SCRIPT}")" && pwd)"
ROOT_DIR="$(cd -- "${REAL_DIR}/../../../../.." && pwd)"
HELPERS_DIR="${ROOT_DIR}/bin/helpers"

if [[ ! -d "$HELPERS_DIR" ]]; then
    echo "Error: helpers directory not found at $HELPERS_DIR" >&2
    exit 1
fi

# Theme path
THEME_FILE="${HOME}/.config/rofi/helpers-menu.rasi"
if [[ ! -f "$THEME_FILE" ]]; then
    THEME_FILE="${ROOT_DIR}/dotfiles/rofi/.config/rofi/helpers-menu.rasi"
fi

# Dynamically discover all executable helpers in HELPERS_DIR
ENTRIES=()
for script in "$HELPERS_DIR"/*.sh; do
    [[ -f "$script" && -x "$script" ]] || continue

    # Parse metadata in pure Bash without external subprocess forks
    title=""
    icon=""
    order=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^(function|[a-zA-Z0-9_]+\(\)|if|for|while|case) ]] && break
        case "$line" in
            HELPER_TITLE=*)
                val="${line#HELPER_TITLE=}"
                val="${val#[\"\']}"
                val="${val%[\"\']}"
                title="$val"
                ;;
            HELPER_ICON=*)
                val="${line#HELPER_ICON=}"
                val="${val#[\"\']}"
                val="${val%[\"\']}"
                icon="$val"
                ;;
            HELPER_ORDER=*)
                val="${line#HELPER_ORDER=}"
                val="${val#[\"\']}"
                val="${val%[\"\']}"
                order="$val"
                ;;
        esac
        if [[ -n "$title" && -n "$icon" && -n "$order" ]]; then
            break
        fi
    done < "$script"

    # Fallback title if not explicitly set
    if [[ -z "$title" ]]; then
        base="$(basename "$script" .sh)"
        title="$(echo "$base" | sed -r 's/(^|-)([a-z])/\U\2/g' | tr '-' ' ')"
    fi

    # Fallback icon if not explicitly set
    if [[ -z "$icon" ]]; then
        icon=""
    fi

    # Fallback order if not explicitly set
    if [[ -z "$order" || ! "$order" =~ ^[0-9]+$ ]]; then
        order=50
    fi

    label="${icon}  ${title}"
    ENTRIES+=("$(printf "%03d|%s|%s" "$order" "$label" "$script")")
done

if [[ ${#ENTRIES[@]} -eq 0 ]]; then
    echo "No executable helpers found in $HELPERS_DIR" >&2
    exit 1
fi

# Sort entries by order, then label
IFS=$'\n' read -r -d '' -a SORTED_ENTRIES < <(printf "%s\n" "${ENTRIES[@]}" | sort && printf "\0")

declare -A SCRIPT_MAP
MENU_ITEMS=""
for entry in "${SORTED_ENTRIES[@]}"; do
    [[ -z "$entry" ]] && continue
    label=$(echo "$entry" | cut -d'|' -f2)
    path=$(echo "$entry" | cut -d'|' -f3)
    SCRIPT_MAP["$label"]="$path"
    if [[ -z "$MENU_ITEMS" ]]; then
        MENU_ITEMS="$label"
    else
        MENU_ITEMS="${MENU_ITEMS}"$'\n'"$label"
    fi
done

# Dry run mode for testing / validation
if [[ "${1:-}" == "--dry-run" ]]; then
    target="${2:-}"
    for label in "${!SCRIPT_MAP[@]}"; do
        script_path="${SCRIPT_MAP[$label]}"
        script_name="$(basename "$script_path")"
        if [[ "$label" == *"$target"* || "$script_name" == *"$target"* ]]; then
            echo "$script_path"
            exit 0
        fi
    done
    echo "Unknown target: $target" >&2
    exit 1
fi

# Launch Rofi
SELECTED=$(echo "$MENU_ITEMS" | rofi -dmenu \
    -theme "$THEME_FILE" \
    -p " " \
    -i)

if [[ -z "$SELECTED" ]]; then
    exit 0
fi

if [[ -n "${SCRIPT_MAP[$SELECTED]:-}" ]]; then
    "${SCRIPT_MAP[$SELECTED]}" &
fi
