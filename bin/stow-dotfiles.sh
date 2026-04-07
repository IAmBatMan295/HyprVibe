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

DOTFILES_DIR="${ROOT_DIR}/dotfiles"
USER_HOME="$(resolve_user_home)"

PACKAGES=(
    foot
    gtk-2.0
    gtk-3.0
    gtk-4.0
    hypr
    kde
    kitty
    mako
    mpd
    mpv
    nvim
    ohmyposh
    qt5ct
    qt6ct
    rmpc
    rofi
    shell-config
    tmux
    waybar
    Code
)

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command not found: $cmd"
        return 1
    fi
}

require_directory() {
    local dir_path="$1"
    if [[ ! -d "$dir_path" ]]; then
        log_error "Required directory missing: $dir_path"
        return 1
    fi
}

is_safe_target_path() {
    local target_path="$1"
    local resolved_home
    local resolved_target

    resolved_home="$(realpath -ms "$USER_HOME")"
    resolved_target="$(realpath -ms "$target_path")"

    if [[ "$resolved_target" == "$resolved_home" || "$resolved_target" == "/" ]]; then
        return 1
    fi

    case "$resolved_target" in
        "$resolved_home/.config/"*|"$resolved_home"/.*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

remove_target_if_exists() {
    local target_path="$1"

    if ! is_safe_target_path "$target_path"; then
        log_error "Unsafe target path for cleanup: $target_path"
        return 1
    fi

    if [[ -L "$target_path" || -e "$target_path" ]]; then
        rm -rf "$target_path"
    fi

    return 0
}

preclean_package_targets() {
    local pkg="$1"
    local pkg_dir="${DOTFILES_DIR}/${pkg}"

    if [[ "$pkg" == "Code" ]]; then
        # VS Code: replace only settings.json, keep extensions/state/cache intact.
        mkdir -p "${USER_HOME}/.config/Code/User"
        remove_target_if_exists "${USER_HOME}/.config/Code/User/settings.json" || return 1
        return 0
    fi

    if [[ -d "${pkg_dir}/.config" ]]; then
        local cfg_entry
        while IFS= read -r -d '' cfg_entry; do
            remove_target_if_exists "${USER_HOME}/.config/$(basename "$cfg_entry")" || return 1
        done < <(find "${pkg_dir}/.config" -mindepth 1 -maxdepth 1 -print0)
    fi

    local top_entry
    while IFS= read -r -d '' top_entry; do
        if [[ "$(basename "$top_entry")" == ".config" ]]; then
            continue
        fi
        remove_target_if_exists "${USER_HOME}/$(basename "$top_entry")" || return 1
    done < <(find "$pkg_dir" -mindepth 1 -maxdepth 1 -name ".*" -print0)

    return 0
}

main() {
    setup_colors

    require_command stow
    require_directory "$DOTFILES_DIR"

    local pkg
    for pkg in "${PACKAGES[@]}"; do
        require_directory "${DOTFILES_DIR}/${pkg}"
    done

    log_phase "Stow Pre-clean"
    log_info "Preparing target paths for repo-first stow behavior"
    for pkg in "${PACKAGES[@]}"; do
        preclean_package_targets "$pkg" || return 1
    done

    log_phase "Stow Apply"
    log_info "Stowing dotfiles packages into ${USER_HOME}"
    cd "$DOTFILES_DIR"
    stow -t "$USER_HOME" "${PACKAGES[@]}"

    log_success "Dotfiles stow step completed successfully."
}

main "$@"