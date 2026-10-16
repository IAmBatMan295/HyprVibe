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

        sudo systemctl enable "$service" || log_warn "Failed to enable $service (chroot?)"
        return 0
    fi

    if ! systemctl --user list-unit-files "$service" >/dev/null 2>&1; then
        log_warn "Skipping missing user service: $service"
        return 0
    fi

    systemctl --user enable "$service" || log_warn "Failed to enable user service $service (chroot?)"
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
    log_info "Enabling global services"
    local service
    for service in "${global_services[@]}"; do
        enable_service_if_present "system" "$service"
    done

    log_info "Disabling Wi-Fi power save"
    sudo mkdir -p /etc/NetworkManager/conf.d
    echo -e "[connection]\nwifi.powersave = 2" | sudo tee /etc/NetworkManager/conf.d/99-disable-wifi-powersave.conf > /dev/null
    sudo systemctl restart NetworkManager || log_warn "Could not restart NetworkManager (expected in chroot)"

    log_info "Configuring UFW rules"
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 53317/tcp
        sudo ufw allow 53317/udp
    else
        log_warn "ufw not found, skipping firewall rules"
    fi

    log_info "Enabling user services"
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

    if [[ -n "${OPEN_SUBTITLES_KEY:-}" && "${OPEN_SUBTITLES_KEY}" != "YOUR_API_KEY_HERE" ]]; then
        log_info "Applying OpenSubtitles key"
        sed -i -E "s|open_subtitles_api_key = .*|open_subtitles_api_key = '${OPEN_SUBTITLES_KEY}',|" "$SCRIPTS_DIR/uosc/main.lua"
    fi

    log_success "uosc + thumbfast install complete"
}

detect_gpu_driver() {
    local gpu_info
    gpu_info="$(lspci -nnk 2>/dev/null | grep -i -EA3 'VGA|3D|Display' || true)"

    if echo "$gpu_info" | grep -iq "Kernel driver in use: amdgpu"; then
        printf '%s\n' "amdgpu"
        return 0
    elif echo "$gpu_info" | grep -iq "Kernel driver in use: i915"; then
        printf '%s\n' "i915"
        return 0
    elif echo "$gpu_info" | grep -iq "Kernel driver in use: xe"; then
        printf '%s\n' "xe"
        return 0
    elif echo "$gpu_info" | grep -iqE "Kernel driver in use: (nvidia|nouveau)"; then
        printf '%s\n' "nvidia"
        return 0
    fi

    if [[ -d /sys/module/amdgpu ]]; then
        printf '%s\n' "amdgpu"
        return 0
    elif [[ -d /sys/module/i915 ]]; then
        printf '%s\n' "i915"
        return 0
    elif [[ -d /sys/module/xe ]]; then
        printf '%s\n' "xe"
        return 0
    fi

    return 1
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

    local gpu_mod
    gpu_mod="$(detect_gpu_driver || true)"

    if [[ "$gpu_mod" == "amdgpu" || "$gpu_mod" == "i915" || "$gpu_mod" == "xe" ]]; then
        log_info "Detected GPU driver (${gpu_mod}). Injecting into mkinitcpio for Early KMS..."
        sudo sed -i -E "/^MODULES=\(/ { /\b${gpu_mod}\b/! s/^MODULES=\(/MODULES=(${gpu_mod} / }" /etc/mkinitcpio.conf
    elif [[ "$gpu_mod" == "nvidia" ]]; then
        log_info "Nvidia GPU detected. Skipping Early KMS module injection."
    else
        log_warn "Unknown or unsupported GPU. Skipping Early KMS module injection."
    fi

    log_info "Applying theme and rebuilding initramfs (-R flag)..."
    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        sudo plymouth-set-default-theme -R glitch || sudo mkinitcpio -P
        log_success "Plymouth early KMS glitch theme applied."
    else
        log_warn "Plymouth CLI missing! Falling back to raw mkinitcpio -P."
        sudo mkinitcpio -P
    fi
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

install_madsnake() {
    log_phase "Install madsnake screensaver"

    local madsnake_dir="$HOME/madsnake"
    if [[ ! -d "$madsnake_dir" ]]; then
        log_info "Cloning madsnake repo to $madsnake_dir"
        if ! git clone https://github.com/IAmBatMan295/madsnake.git "$madsnake_dir"; then
            log_error "Failed to clone madsnake repository"
            return 1
        fi
    else
        log_info "madsnake repo already exists at $madsnake_dir, pulling latest"
        if ! git -C "$madsnake_dir" pull; then
            log_error "Failed to update madsnake repository"
            return 1
        fi
    fi

    log_info "Running madsnake install.sh"
    if ! (cd "$madsnake_dir" && bash install.sh); then
        log_error "madsnake install.sh failed"
        return 1
    fi

    log_success "madsnake install complete"
}

main() {
    setup_colors

    log_info "Validating sudo credentials for miscellaneous tasks..."
    if ! sudo -v; then
        log_error "Sudo authorization failed."
        exit 1
    fi

    install_uosc_stack
    setup_plymouth_glitch
    configure_flatpak_themes
    configure_gsettings
    install_madsnake
    enable_services
}

main "$@"
