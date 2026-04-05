#!/usr/bin/env bash

set -uE -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PACKAGES_DIR="${ROOT_DIR}/packages"
PACMAN_LIST=""
YAY_LIST=""
PACKAGE_PROFILE=""
MIN_ATTEMPTS=3

read_from_tty() {
    local prompt="$1"
    local out_var="$2"
    local input=""

    if [[ -r /dev/tty ]]; then
        if ! read -r -p "$prompt" input </dev/tty; then
            return 1
        fi
    else
        if ! read -r -p "$prompt" input; then
            return 1
        fi
    fi

    printf -v "$out_var" '%s' "$input"
    return 0
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
                echo "Error: HYPRVIBE_PACKAGE_PROFILE must be either 'cachy' or 'arch'."
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
            echo "Error: Unsupported package profile: $PACKAGE_PROFILE"
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
        echo "Error: Missing file: $file_path"
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

is_installed() {
    local pkg="$1"
    pacman -Q "$pkg" >/dev/null 2>&1
}

missing_packages() {
    local -n all_pkgs="$1"
    local -n missing_out="$2"
    missing_out=()

    local pkg
    for pkg in "${all_pkgs[@]}"; do
        if ! is_installed "$pkg"; then
            missing_out+=("$pkg")
        fi
    done
}

prompt_retry() {
    local attempt="$1"
    local step_name="$2"
    local next_attempt=$((attempt + 1))
    local answer

    while true; do
        if ! read_from_tty "$step_name failed on attempt ${attempt}. Retry with attempt ${next_attempt}? [y/N]: " answer; then
            echo "Error: Interactive input unavailable. Cannot continue retry loop for ${step_name}."
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
                echo "Please answer yes or no."
                ;;
        esac
    done
}

run_with_retries() {
    local step_name="$1"
    local command_fn="$2"
    local verify_fn="$3"
    local attempt=1

    while true; do
        echo ""
        echo "==> ${step_name}: attempt ${attempt}"

        if "$command_fn" && "$verify_fn"; then
            echo "==> ${step_name}: success"
            return 0
        fi

        if (( attempt < MIN_ATTEMPTS )); then
            echo "==> ${step_name}: failed (minimum target is ${MIN_ATTEMPTS} attempts)"
        else
            echo "==> ${step_name}: failed after ${attempt} attempt(s)"
        fi

        if ! prompt_retry "$attempt" "$step_name"; then
            echo "Aborted by user during ${step_name}."
            return 1
        fi

        ((attempt++))
    done
}

bootstrap_yay_once() {
    if command -v yay >/dev/null 2>&1; then
        return 0
    fi

    echo "==> yay not found. Installing from AUR git repository"
    sudo pacman -S --needed --noconfirm base-devel git || return 1

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

    if ! makepkg -si --noconfirm; then
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
            echo "==> cachyos-rate-mirrors not found. Installing it first"
            sudo pacman -S --needed --noconfirm cachyos-rate-mirrors || return 1
        fi

        echo "==> Running cachyos-rate-mirrors for CachyOS mirrorlists"
        sudo cachyos-rate-mirrors
        echo "==> cachyos-rate-mirrors completed"
        return 0
    fi

    if ! command -v reflector >/dev/null 2>&1; then
        echo "==> reflector not found. Installing reflector first"
        sudo pacman -S --needed --noconfirm reflector || return 1
    fi

    run_reflector_for_target "/etc/pacman.d/mirrorlist" || return 1
}

run_reflector_for_target() {
    local target_file="$1"

    echo "==> Running reflector to refresh ${target_file}"
    echo "==> Command: sudo reflector --country India,Singapore,Taiwan,Japan --age 12 --protocol https --sort rate --latest 20 --save ${target_file}"
    sudo reflector --country India,Singapore,Taiwan,Japan --age 12 --protocol https --sort rate --latest 20 --save "$target_file"
    echo "==> reflector completed"
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

install_pacman_once() {
    if (( ${#PACMAN_PKGS[@]} == 0 )); then
        return 0
    fi

    sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}"
}

verify_pacman_install() {
    local missing=()
    missing_packages PACMAN_PKGS missing

    if (( ${#missing[@]} > 0 )); then
        echo "Missing pacman packages: ${missing[*]}"
        return 1
    fi

    return 0
}

install_yay_packages_once() {
    if (( ${#YAY_PKGS[@]} == 0 )); then
        return 0
    fi

    yay -S --needed --noconfirm --sudoloop "${YAY_PKGS[@]}"
}

verify_yay_install() {
    local missing=()
    missing_packages YAY_PKGS missing

    if (( ${#missing[@]} > 0 )); then
        echo "Missing yay packages: ${missing[*]}"
        return 1
    fi

    return 0
}

main() {
    if [[ "${EUID}" -eq 0 ]]; then
        echo "Please run this script as a normal user with sudo privileges, not as root."
        exit 1
    fi

    detect_package_profile || exit 1
    set_package_files || exit 1
    echo "Using package profile: ${PACKAGE_PROFILE}"

    require_file "$PACMAN_LIST"
    require_file "$YAY_LIST"
    load_packages "$PACMAN_LIST" PACMAN_PKGS
    load_packages "$YAY_LIST" YAY_PKGS

    run_with_retries "Setup reflector mirrors" setup_reflector_once verify_reflector_setup
    run_with_retries "Install pacman packages" install_pacman_once verify_pacman_install
    run_with_retries "Install yay helper" bootstrap_yay_once bootstrap_yay_verify
    run_with_retries "Install yay packages" install_yay_packages_once verify_yay_install

    echo ""
    echo "All package installation steps completed successfully."
}

main "$@"