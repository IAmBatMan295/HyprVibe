#!/bin/bash

if ! command -v cliphist >/dev/null 2>&1; then
    notify-send -u critical "Clipboard Menu" "cliphist is not installed" 2>/dev/null || true
    exit 1
fi

# 1. Get History
HISTORY_SNAPSHOT=$(cliphist list | head -n 20)

# 2. Options
CLEAR_OPTION="  Clear History"
EMPTY_MESSAGE="   [Empty]"

if [ -z "$HISTORY_SNAPSHOT" ]; then
    MENU_ITEMS="$EMPTY_MESSAGE"
else
    # Map IDs
    mapfile -t CLIPHIST_IDS < <(echo "$HISTORY_SNAPSHOT" | awk '{print $1}')
    # Format List: Strip binary tags, remove IDs, number them in single sed | awk pass
    MENU_ITEMS=$(echo "$HISTORY_SNAPSHOT" | \
                 sed -E 's/\[\[ binary data (.*) \]\]/[\1]/' | \
                 awk '{$1=""; sub(/^[ \t]+/, ""); printf "%d. %s\n", NR, $0}')
fi

FINAL_MENU=$(printf "%s\n%s" "$MENU_ITEMS" "$CLEAR_OPTION")

# 3. Launch Rofi with the Card Theme
SELECTED_ITEM=$(echo "$FINAL_MENU" | rofi -dmenu \
    -theme "${HOME}/.config/rofi/clipboard-menu.rasi" \
    -p " " \
    -i)

# 4. Logic
if [ -z "$SELECTED_ITEM" ]; then exit 0; fi

if [ "$SELECTED_ITEM" = "$CLEAR_OPTION" ]; then
    cliphist wipe
    wl-copy --clear
    exit 0
fi

if [ "$SELECTED_ITEM" = "$EMPTY_MESSAGE" ]; then exit 0; fi

# Extract ID in pure Bash and Copy
LINE_NUMBER="${SELECTED_ITEM%%.*}"
LINE_NUMBER="${LINE_NUMBER//[[:space:]]/}"
if [[ -z "$LINE_NUMBER" || ! "$LINE_NUMBER" =~ ^[0-9]+$ || "$LINE_NUMBER" -le 0 ]]; then
    exit 0
fi

ARRAY_INDEX=$((LINE_NUMBER - 1))
if [[ -z "${CLIPHIST_IDS[ARRAY_INDEX]:-}" ]]; then
    exit 0
fi

ID_TO_COPY=${CLIPHIST_IDS[ARRAY_INDEX]}

cliphist decode "$ID_TO_COPY" | wl-copy
