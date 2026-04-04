#!/usr/bin/env bash

set -euo pipefail

MPV_DIR="${HOME}/.config/mpv"
SCRIPTS_DIR="${MPV_DIR}/scripts"
SCRIPT_OPTS_DIR="${MPV_DIR}/script-opts"
UOSC_KEY="b0rd16N0bp7DETMpO4pYZwIqmQkZbYQr"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

install_uosc_stack() {
    echo "==> Installing latest uosc"
    curl -fsSL "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip" -o "$TMP_DIR/uosc.zip"
    unzip -oq "$TMP_DIR/uosc.zip" -d "$MPV_DIR"

    echo "==> Installing latest uosc.conf"
    curl -fsSL "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf" -o "$SCRIPT_OPTS_DIR/uosc.conf"

    echo "==> Installing thumbfast"
    curl -fsSL "https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua" -o "$SCRIPTS_DIR/thumbfast.lua"
    curl -fsSL "https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.conf" -o "$SCRIPT_OPTS_DIR/thumbfast.conf"

    echo "==> Applying OpenSubtitles key"
    sed -i -E "s|open_subtitles_api_key = .*|open_subtitles_api_key = '${UOSC_KEY}',|" "$SCRIPTS_DIR/uosc/main.lua"

    echo "==> uosc + thumbfast install complete"
}

main() {
    install_uosc_stack
}

main "$@"
