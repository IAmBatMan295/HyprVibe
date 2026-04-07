#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="${SCRIPT_DIR}/lib/common.sh"

if [[ ! -r "$COMMON_LIB" ]]; then
    echo "Error: Missing common helper library: $COMMON_LIB" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$COMMON_LIB"

USER_HOME="$(resolve_user_home)"

MPV_DIR="${USER_HOME}/.config/mpv"
SCRIPTS_DIR="${MPV_DIR}/scripts"
SCRIPT_OPTS_DIR="${MPV_DIR}/script-opts"
UOSC_KEY="b0rd16N0bp7DETMpO4pYZwIqmQkZbYQr"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

ensure_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command not found: $cmd"
        return 1
    fi
}

download_file() {
    local url="$1"
    local destination="$2"
    local tmp_file="${TMP_DIR}/$(basename "$destination").tmp"

    mkdir -p "$(dirname "$destination")" || return 1

    curl -fL --retry 5 --retry-delay 2 --retry-connrefused --connect-timeout 20 \
        "$url" -o "$tmp_file" || return 1

    mv -f "$tmp_file" "$destination"
}

enable_service_if_present() {
    local mode="$1"
    local service="$2"

    if [[ "$mode" == "system" ]]; then
        if ! systemctl list-unit-files "$service" >/dev/null 2>&1; then
            log_warn "Skipping missing system service: $service"
            return 0
        fi

        sudo systemctl enable --now "$service"
        return 0
    fi

    if ! systemctl --user list-unit-files "$service" >/dev/null 2>&1; then
        log_warn "Skipping missing user service: $service"
        return 0
    fi

    systemctl --user enable --now "$service"
}

enable_services() {
    local -a global_services=(
        "NetworkManager.service"
        "sddm.service"
        "preload.service"
        "bluetooth.service"
    )

    local -a user_services=(
        "mpd.service"
        "mpDris2.service"
        "wireplumber.service"
    )

    log_phase "Service Enablement"
    log_info "Enabling global services with --now"
    local service
    for service in "${global_services[@]}"; do
        enable_service_if_present "system" "$service"
    done

    log_info "Enabling user services with --now"
    for service in "${user_services[@]}"; do
        enable_service_if_present "user" "$service"
    done

    log_success "Service enablement completed"
}

install_uosc_stack() {
    ensure_command curl
    ensure_command unzip

    mkdir -p "$MPV_DIR" "$SCRIPTS_DIR" "$SCRIPT_OPTS_DIR"

    log_phase "uosc + thumbfast"
    log_info "Installing latest uosc"
    download_file "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip" "$TMP_DIR/uosc.zip"
    unzip -oq "$TMP_DIR/uosc.zip" -d "$MPV_DIR"

    log_info "Installing latest uosc.conf"
    download_file "https://github.com/tomasklaen/uosc/releases/latest/download/uosc.conf" "$SCRIPT_OPTS_DIR/uosc.conf"

    log_info "Installing thumbfast"
    download_file "https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua" "$SCRIPTS_DIR/thumbfast.lua"
    download_file "https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.conf" "$SCRIPT_OPTS_DIR/thumbfast.conf"

    if [[ ! -f "$SCRIPTS_DIR/uosc/main.lua" ]]; then
        log_error "uosc main.lua was not found after extraction."
        return 1
    fi

    log_info "Applying OpenSubtitles key"
    sed -i -E "s|open_subtitles_api_key = .*|open_subtitles_api_key = '${UOSC_KEY}',|" "$SCRIPTS_DIR/uosc/main.lua"

    log_success "uosc + thumbfast install complete"
}

main() {
    setup_colors

    install_uosc_stack
    enable_services
}

main "$@"
