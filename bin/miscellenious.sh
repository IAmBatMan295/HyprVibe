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

mkdir -p "${USER_HOME}/Pictures/Screenshots" "${USER_HOME}/Pictures/Recordings"

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

prepare_mpd_environment() {
    local mpd_config_dir="${USER_HOME}/.config/mpd"
    local mpd_config_file="${mpd_config_dir}/mpd.conf"
    local mpd_playlists_dir="${mpd_config_dir}/playlists"
    local mpd_music_dir="${USER_HOME}/Music/music"

    log_info "Preparing MPD directories"
    mkdir -p "$mpd_config_dir" "$mpd_playlists_dir" "$mpd_music_dir"

    if [[ ! -f "$mpd_config_file" ]]; then
        log_warn "MPD config not found at ${mpd_config_file}; ensure dotfiles stow ran before this step."
    fi
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
    prepare_mpd_environment
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

setup_plymouth_glitch() {
    log_phase "Plymouth & Early KMS Setup"

    local plymouth_local_dir="${SCRIPT_DIR}/../plymouth-theme/glitch"
    local sys_plymouth_dir="/usr/share/plymouth/themes/glitch"

    if [[ -d "$plymouth_local_dir" ]]; then
        log_info "Installing Plymouth 'glitch' theme from repository"
        sudo cp -a "$plymouth_local_dir" "/usr/share/plymouth/themes/"
    else
        log_warn "Plymouth theme 'glitch' not found in $plymouth_local_dir. Assuming already installed or skipping default copy."
    fi

    log_info "Injecting amdgpu into mkinitcpio for Early KMS..."
    sudo sed -i -E '/^MODULES=\(/ { /\bamdgpu\b/! s/^MODULES=\(/MODULES=(amdgpu / }' /etc/mkinitcpio.conf

    log_info "Applying theme and rebuilding initramfs (-R flag)..."
    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        sudo plymouth-set-default-theme -R glitch || sudo mkinitcpio -P
        log_success "Plymouth early KMS glitch theme applied."
    else
        log_warn "Plymouth CLI missing! Falling back to raw mkinitcpio -P."
        sudo mkinitcpio -P
    fi
}

setup_grub_theme() {
    log_phase "GRUB Theme Setup"

    local grub_local_dir="${SCRIPT_DIR}/../grub-theme/CRT-Amber-GRUB-Theme"
    local sys_grub_dir="/usr/share/grub/themes/CRT-Amber-GRUB-Theme"
    local theme_txt_path="${sys_grub_dir}/theme.txt"

    if [[ -d "$grub_local_dir" ]]; then
        log_info "Installing GRUB 'CRT-Amber' theme from repository"
        sudo mkdir -p "/usr/share/grub/themes/"
        sudo cp -a "$grub_local_dir" "/usr/share/grub/themes/"
    else
        log_warn "GRUB theme not found in $grub_local_dir. Assuming already installed."
    fi

    log_info "Updating /etc/default/grub..."
    # Idempotent inject or replace GRUB_THEME
    if grep -q "^GRUB_THEME=" /etc/default/grub; then
        sudo sed -i -E "s|^GRUB_THEME=.*|GRUB_THEME='${theme_txt_path}'|g" /etc/default/grub
    else
        echo "GRUB_THEME='${theme_txt_path}'" | sudo tee -a /etc/default/grub >/dev/null
    fi

    log_info "Enabling GRUB OS Prober for dual boot..."
    sudo sed -i -E 's|^#?GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|' /etc/default/grub

    log_info "Rebuilding GRUB config..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    log_success "GRUB theme applied."
}

configure_flatpak_themes() {
    log_phase "Flatpak Themes"
    
    if ! command -v flatpak >/dev/null 2>&1; then
        log_warn "Flatpak missing. Skip."
        return 0
    fi

    log_info "Override flatpak to dark theme"
    flatpak override --user --filesystem="$HOME/.themes"
    flatpak override --user --filesystem="$HOME/.icons"
    flatpak override --user --filesystem="$HOME/.local/share/themes"
    flatpak override --user --filesystem="$HOME/.local/share/icons"
    flatpak override --user --filesystem="$HOME/.config/gtk-3.0:ro"
    flatpak override --user --filesystem="$HOME/.config/gtk-4.0:ro"
    flatpak override --user --env=GTK_THEME=adw-gtk3-dark
    
    log_success "Flatpak dark theme done"
}

configure_gsettings() {
    log_phase "GSettings Configuration"

    if ! command -v gsettings >/dev/null 2>&1; then
        log_warn "gsettings missing. Skip."
        return 0
    fi

    log_info "Set prefer-dark and foot terminal"
    
    # Dark mode
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    
    # Terminal for various DE schemas (silently fail if schema does not exist)
    gsettings set org.gnome.desktop.default-applications.terminal exec 'foot' 2>/dev/null || true
    gsettings set org.cinnamon.desktop.default-applications.terminal exec 'foot' 2>/dev/null || true
    gsettings set org.mate.applications-terminal exec 'foot' 2>/dev/null || true
    
    log_success "GSettings done"
}

main() {
    setup_colors

    log_info "Requesting sudo privileges upfront to avoid mid-script stalls..."
    sudo -v
    # Keep-alive sudo to prevent timeout during long operations
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    install_uosc_stack
    setup_plymouth_glitch
    setup_grub_theme
    configure_flatpak_themes
    configure_gsettings
    enable_services
}

main "$@"
