#!/usr/bin/env bash

set -uE -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
DOTFILES_DIR="${ROOT_DIR}/dotfiles"

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
        echo "Error: Required command not found: $cmd"
        return 1
    fi
}

require_directory() {
    local dir_path="$1"
    if [[ ! -d "$dir_path" ]]; then
        echo "Error: Required directory missing: $dir_path"
        return 1
    fi
}

remove_target_if_exists() {
    local target_path="$1"
    if [[ -L "$target_path" || -e "$target_path" ]]; then
        rm -rf "$target_path"
    fi
}

preclean_package_targets() {
    local pkg="$1"
    local pkg_dir="${DOTFILES_DIR}/${pkg}"

    if [[ "$pkg" == "Code" ]]; then
        # VS Code: replace only settings.json, keep extensions/state/cache intact.
        mkdir -p "${HOME}/.config/Code/User"
        remove_target_if_exists "${HOME}/.config/Code/User/settings.json"
        return 0
    fi

    if [[ -d "${pkg_dir}/.config" ]]; then
        local cfg_entry
        while IFS= read -r -d '' cfg_entry; do
            remove_target_if_exists "${HOME}/.config/$(basename "$cfg_entry")"
        done < <(find "${pkg_dir}/.config" -mindepth 1 -maxdepth 1 -print0)
    fi

    local top_entry
    while IFS= read -r -d '' top_entry; do
        if [[ "$(basename "$top_entry")" == ".config" ]]; then
            continue
        fi
        remove_target_if_exists "${HOME}/$(basename "$top_entry")"
    done < <(find "$pkg_dir" -mindepth 1 -maxdepth 1 -name ".*" -print0)
}

main() {
    require_command stow
    require_directory "$DOTFILES_DIR"

    local pkg
    for pkg in "${PACKAGES[@]}"; do
        require_directory "${DOTFILES_DIR}/${pkg}"
    done

    echo "==> Preparing target paths for repo-first stow behavior"
    for pkg in "${PACKAGES[@]}"; do
        preclean_package_targets "$pkg"
    done

    echo "==> Stowing dotfiles packages into ${HOME}"
    cd "$DOTFILES_DIR"
    stow -t "$HOME" "${PACKAGES[@]}"

    echo "==> Dotfiles stow step completed successfully."
}

main "$@"