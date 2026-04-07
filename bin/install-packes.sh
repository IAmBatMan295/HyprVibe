#!/usr/bin/env bash

set -uE -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
COMMON_LIB="${SCRIPT_DIR}/lib/common.sh"

if [[ ! -r "$COMMON_LIB" ]]; then
    echo "Error: Missing common helper library: $COMMON_LIB" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$COMMON_LIB"

PACKAGES_DIR="${ROOT_DIR}/packages"
PACMAN_LIST=""
YAY_LIST=""
PACKAGE_PROFILE=""
MIN_ATTEMPTS=3
PACMAN_SYSUPGRADE_DONE=0

YAY_INSTALL_FLAGS=(
    --needed
    --sudoloop
    --useask
    --answerclean None
    --answerdiff None
    --answeredit None
    --answerupgrade None
    --noremovemake
)

run_with_tty_stdin() {
    if [[ -r /dev/tty ]]; then
        "$@" </dev/tty
    else
        "$@"
    fi
}

detect_package_profile() {
    local requested_profile="${HYPRVIBE_PACKAGE_PROFILE:-}"

    if [[ -n "$requested_profile" ]]; then
        case "${requested_profile,,}" in
            cachy|arch)
                PACKAGE_PROFILE="${requested_profile,,}"
                return 0
                ;;
            *)
                log_error "HYPRVIBE_PACKAGE_PROFILE must be either 'cachy' or 'arch'."
                return 1
                ;;
        esac
    fi

    local os_id=""
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os_id="${ID:-}"
    fi

    case "${os_id,,}" in
        cachyos)
            PACKAGE_PROFILE="cachy"
            ;;
        *)
            PACKAGE_PROFILE="arch"
            ;;
    esac
}

set_package_files() {
    case "$PACKAGE_PROFILE" in
        cachy)
            PACMAN_LIST="${PACKAGES_DIR}/cachy-pacman.txt"
            YAY_LIST="${PACKAGES_DIR}/cachy-yay.txt"
            ;;
        arch)
            PACMAN_LIST="${PACKAGES_DIR}/arch-pacman.txt"
            YAY_LIST="${PACKAGES_DIR}/arch-yay.txt"
            ;;
        *)
            log_error "Unsupported package profile: $PACKAGE_PROFILE"
            return 1
            ;;
    esac
}

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

require_file() {
    local file_path="$1"
    if [[ ! -f "$file_path" ]]; then
        log_error "Missing file: $file_path"
        exit 1
    fi
}

load_packages() {
    local file_path="$1"
    local -n out_array="$2"
    out_array=()

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        local line
        line="${raw_line%%#*}"
        line="$(trim "$line")"
        if [[ -n "$line" ]]; then
            out_array+=("$line")
        fi
    done < "$file_path"
}

declare -A INSTALLED_PKG_MAP=()
INSTALLED_CACHE_VALID=0

refresh_installed_pkg_cache() {
    INSTALLED_PKG_MAP=()

    local installed_pkg=""
    while IFS= read -r installed_pkg; do
        if [[ -n "$installed_pkg" ]]; then
            INSTALLED_PKG_MAP["$installed_pkg"]=1
        fi
    done < <(pacman -Qq)

    INSTALLED_CACHE_VALID=1
}

invalidate_installed_pkg_cache() {
    INSTALLED_CACHE_VALID=0
}

ensure_installed_pkg_cache() {
    if (( INSTALLED_CACHE_VALID == 0 )); then
        refresh_installed_pkg_cache
    fi
}

missing_packages() {
    local -n all_pkgs="$1"
    local -n missing_out="$2"
    missing_out=()

    ensure_installed_pkg_cache

    local pkg
    for pkg in "${all_pkgs[@]}"; do
        if [[ -z "${INSTALLED_PKG_MAP[$pkg]+x}" ]]; then
            missing_out+=("$pkg")
        fi
    done
}

missing_packages_with_providers() {
    local -n all_pkgs="$1"
    local -n missing_out="$2"
    missing_out=()

    ensure_installed_pkg_cache

    local pkg
    local unresolved
    for pkg in "${all_pkgs[@]}"; do
        if [[ -n "${INSTALLED_PKG_MAP[$pkg]+x}" ]]; then
            continue
        fi

        unresolved="$(pacman -T "$pkg" 2>/dev/null || true)"
        if [[ -n "$unresolved" ]]; then
            missing_out+=("$pkg")
        fi
    done
}

should_run_mirror_ranking() {
    local answer

    while true; do
        if ! read_from_tty "Run mirror ranking now? [Y/n]: " answer; then
            log_warn "Interactive input unavailable; proceeding with mirror ranking."
            return 0
        fi

        case "${answer,,}" in
            y|yes|"")
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                log_warn "Please answer yes or no."
                ;;
        esac
    done
}

should_run_post_pacman_recheck() {
    local answer

    while true; do
        if ! read_from_tty "Run post-pacman missing-package recheck pass? [Y/n]: " answer; then
            log_warn "Interactive input unavailable; running post-pacman recheck."
            return 0
        fi

        case "${answer,,}" in
            y|yes|"")
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                log_warn "Please answer yes or no."
                ;;
        esac
    done
}

should_run_slow_fallback() {
    local manager_name="$1"
    local answer

    while true; do
        if ! read_from_tty "Bulk ${manager_name} install failed. Run slower package-by-package fallback? [y/N]: " answer; then
            log_warn "Interactive input unavailable; skipping package-by-package fallback."
            return 1
        fi

        case "${answer,,}" in
            y|yes)
                return 0
                ;;
            n|no|"")
                return 1
                ;;
            *)
                log_warn "Please answer yes or no."
                ;;
        esac
    done
}

bootstrap_yay_once() {
    if command -v yay >/dev/null 2>&1; then
        return 0
    fi

    log_info "yay not found. Installing from AUR git repository"
    run_with_tty_stdin sudo pacman -S --needed base-devel git || return 1

    local tmp_dir
    tmp_dir="$(mktemp -d)" || return 1

    if ! git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"; then
        rm -rf "$tmp_dir"
        return 1
    fi

    pushd "$tmp_dir/yay" >/dev/null || {
        rm -rf "$tmp_dir"
        return 1
    }

    if ! run_with_tty_stdin makepkg -si; then
        popd >/dev/null
        rm -rf "$tmp_dir"
        return 1
    fi

    popd >/dev/null
    rm -rf "$tmp_dir"

    command -v yay >/dev/null 2>&1
}

bootstrap_yay_verify() {
    command -v yay >/dev/null 2>&1
}

setup_reflector_once() {
    if [[ "$PACKAGE_PROFILE" == "cachy" ]]; then
        if ! command -v cachyos-rate-mirrors >/dev/null 2>&1; then
            log_info "cachyos-rate-mirrors not found. Installing it first"
            run_with_tty_stdin sudo pacman -S --needed cachyos-rate-mirrors || return 1
        fi

        log_info "Running cachyos-rate-mirrors for CachyOS mirrorlists"
        sudo cachyos-rate-mirrors
        log_success "cachyos-rate-mirrors completed"
        return 0
    fi

    if ! command -v reflector >/dev/null 2>&1; then
        log_info "reflector not found. Installing reflector first"
        run_with_tty_stdin sudo pacman -S --needed reflector || return 1
    fi

    run_reflector_for_target "/etc/pacman.d/mirrorlist" || return 1
}

run_reflector_for_target() {
    local target_file="$1"

    log_info "Running reflector to refresh ${target_file}"
    log_info "Command: sudo reflector --country India,Singapore,Taiwan,Japan --age 12 --protocol https --sort rate --latest 20 --save ${target_file}"
    sudo reflector --country India,Singapore,Taiwan,Japan --age 12 --protocol https --sort rate --latest 20 --save "$target_file"
    log_success "reflector completed"
}

verify_reflector_setup() {
    if [[ "$PACKAGE_PROFILE" == "cachy" ]]; then
        command -v cachyos-rate-mirrors >/dev/null 2>&1
        return
    fi

    command -v reflector >/dev/null 2>&1
}

PACMAN_PKGS=()
YAY_PKGS=()

sync_and_upgrade_system_once() {
    if (( PACMAN_SYSUPGRADE_DONE == 1 )); then
        return 0
    fi

    log_phase "System Sync"
    log_info "Syncing package databases and upgrading system packages first"
    log_info "This prevents dependency breakage during large package installs"
    run_with_tty_stdin sudo pacman -Syu || return 1
    invalidate_installed_pkg_cache

    PACMAN_SYSUPGRADE_DONE=1
    return 0
}

install_pacman_with_fallback() {
    local -a targets=("$@")
    local -a failed=()
    local pkg

    if (( ${#targets[@]} == 0 )); then
        return 0
    fi

    if run_with_tty_stdin sudo pacman -S --needed --ask=4 "${targets[@]}"; then
        invalidate_installed_pkg_cache
        return 0
    fi

    invalidate_installed_pkg_cache

    if ! should_run_slow_fallback "pacman"; then
        log_warn "Skipping package-by-package pacman fallback"
        return 1
    fi

    log_warn "Bulk pacman transaction failed; retrying package-by-package"

    for pkg in "${targets[@]}"; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            continue
        fi

        log_info "Installing pacman package: ${pkg}"
        if ! run_with_tty_stdin sudo pacman -S --needed --ask=4 "$pkg"; then
            failed+=("$pkg")
        fi
    done

    if (( ${#failed[@]} > 0 )); then
        invalidate_installed_pkg_cache
        log_error "Pacman packages still failing: ${failed[*]}"
        return 1
    fi

    invalidate_installed_pkg_cache

    return 0
}

install_yay_with_fallback() {
    local -a targets=("$@")
    local -a failed=()
    local pkg
    local unresolved

    if (( ${#targets[@]} == 0 )); then
        return 0
    fi

    if run_with_tty_stdin yay -S "${YAY_INSTALL_FLAGS[@]}" "${targets[@]}"; then
        invalidate_installed_pkg_cache
        return 0
    fi

    invalidate_installed_pkg_cache

    if ! should_run_slow_fallback "yay"; then
        log_warn "Skipping package-by-package yay fallback"
        return 1
    fi

    log_warn "Bulk yay transaction failed; retrying package-by-package"

    for pkg in "${targets[@]}"; do
        unresolved="$(pacman -T "$pkg" 2>/dev/null || true)"
        if [[ -z "$unresolved" ]]; then
            continue
        fi

        log_info "Installing yay package: ${pkg}"
        if ! run_with_tty_stdin yay -S "${YAY_INSTALL_FLAGS[@]}" "$pkg"; then
            failed+=("$pkg")
        fi
    done

    if (( ${#failed[@]} > 0 )); then
        invalidate_installed_pkg_cache
        log_error "Yay packages still failing: ${failed[*]}"
        return 1
    fi

    invalidate_installed_pkg_cache

    return 0
}

install_pacman_once() {
    if (( ${#PACMAN_PKGS[@]} == 0 )); then
        return 0
    fi

    local missing=()
    missing_packages PACMAN_PKGS missing

    if (( ${#missing[@]} == 0 )); then
        log_success "All pacman packages are already installed; skipping pacman install"
        return 0
    fi

    sync_and_upgrade_system_once || return 1

    log_info "Installing ${#missing[@]} missing pacman package(s)"
    install_pacman_with_fallback "${missing[@]}"
}

verify_pacman_install() {
    local missing=()
    missing_packages PACMAN_PKGS missing

    if (( ${#missing[@]} > 0 )); then
        log_error "Missing pacman packages: ${missing[*]}"
        return 1
    fi

    return 0
}

install_yay_packages_once() {
    if (( ${#YAY_PKGS[@]} == 0 )); then
        return 0
    fi

    local missing=()
    missing_packages_with_providers YAY_PKGS missing

    if (( ${#missing[@]} == 0 )); then
        log_success "All yay packages are already installed; skipping yay install"
        return 0
    fi

    log_info "Installing ${#missing[@]} missing yay package(s)"
    install_yay_with_fallback "${missing[@]}"
}

verify_yay_install() {
    local missing=()
    missing_packages_with_providers YAY_PKGS missing

    if (( ${#missing[@]} > 0 )); then
        log_error "Missing yay packages: ${missing[*]}"
        return 1
    fi

    return 0
}

main() {
    setup_colors

    if [[ "${EUID}" -eq 0 ]]; then
        log_error "Please run this script as a normal user with sudo privileges, not as root."
        exit 1
    fi

    detect_package_profile || exit 1
    set_package_files || exit 1
    log_phase "Package Profile"
    log_info "Using package profile: ${PACKAGE_PROFILE}"

    require_file "$PACMAN_LIST"
    require_file "$YAY_LIST"
    load_packages "$PACMAN_LIST" PACMAN_PKGS
    load_packages "$YAY_LIST" YAY_PKGS

    if should_run_mirror_ranking; then
        run_with_retries "Setup reflector mirrors" setup_reflector_once verify_reflector_setup || exit 1
    else
        log_warn "Skipping mirror ranking by user choice"
    fi

    run_with_retries "Install pacman packages" install_pacman_once verify_pacman_install || exit 1

    if should_run_post_pacman_recheck; then
        run_with_retries "Post-pacman missing package pass" install_pacman_once verify_pacman_install || exit 1
    else
        log_warn "Skipping post-pacman missing-package recheck by user choice"
    fi

    run_with_retries "Install yay helper" bootstrap_yay_once bootstrap_yay_verify || exit 1
    run_with_retries "Install yay packages" install_yay_packages_once verify_yay_install || exit 1

    log_phase "Package Installer Summary"
    log_success "All package installation steps completed successfully."
}

main "$@"