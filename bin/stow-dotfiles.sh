#!/usr/bin/env bash

set -euE -o pipefail

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
    btop
    foot
    gtk-2.0
    gtk-3.0
    gtk-4.0
    hypr
    madsnake
    mako
    mpd
    mpv
    nvim
    ohmyposh
    quickshell
    rmpc
    rofi
    shell-config
    tmux
    xfce4
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

backup_and_prepare_target() {
    local target_path="$1"

    if ! is_safe_target_path "$target_path"; then
        log_error "Unsafe target path for cleanup: $target_path"
        return 1
    fi

    # If it is a symlink pointing directly into DOTFILES_DIR, unlinking is safe and expected
    if [[ -L "$target_path" ]]; then
        local link_dest
        link_dest="$(readlink -f "$target_path" 2>/dev/null || true)"
        if [[ "$link_dest" == "${DOTFILES_DIR}"/* ]]; then
            rm -f "$target_path"
            return 0
        fi
    fi

    # If it exists as a real file, directory, or non-repo symlink, back it up
    if [[ -e "$target_path" || -L "$target_path" ]]; then
        local backup_path="${target_path}.hyprvibe_bak_$(date +%Y%m%d_%H%M%S)"
        log_warn "Existing path detected at ${target_path}. Backing up to ${backup_path}"
        if ! mv "$target_path" "$backup_path"; then
            log_error "Failed to backup ${target_path} to ${backup_path}"
            return 1
        fi
    fi

    return 0
}

preclean_package_targets() {
    local pkg="$1"
    local pkg_dir="${DOTFILES_DIR}/${pkg}"

    if [[ -d "${pkg_dir}/.config" ]]; then
        local cfg_entry
        while IFS= read -r -d '' cfg_entry; do
            backup_and_prepare_target "${USER_HOME}/.config/$(basename "$cfg_entry")" || return 1
        done < <(find "${pkg_dir}/.config" -mindepth 1 -maxdepth 1 -print0)
    fi

    if [[ -d "${pkg_dir}/.local/share" ]]; then
        local share_entry
        while IFS= read -r -d '' share_entry; do
            backup_and_prepare_target "${USER_HOME}/.local/share/$(basename "$share_entry")" || return 1
        done < <(find "${pkg_dir}/.local/share" -mindepth 1 -maxdepth 1 -print0)
    fi

    if [[ -d "${pkg_dir}/.local/bin" ]]; then
        local bin_entry
        while IFS= read -r -d '' bin_entry; do
            backup_and_prepare_target "${USER_HOME}/.local/bin/$(basename "$bin_entry")" || return 1
        done < <(find "${pkg_dir}/.local/bin" -mindepth 1 -maxdepth 1 -print0)
    fi

    local top_entry
    while IFS= read -r -d '' top_entry; do
        local bname="$(basename "$top_entry")"
        if [[ "$bname" == ".config" || "$bname" == ".local" ]]; then
            continue
        fi
        backup_and_prepare_target "${USER_HOME}/${bname}" || return 1
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
    log_info "Preparing target paths with zero-loss backup"
    for pkg in "${PACKAGES[@]}"; do
        preclean_package_targets "$pkg" || return 1
    done

    log_phase "Stow Apply"
    log_info "Processing file templates..."
    if [[ -f "${ROOT_DIR}/templates/xfce4/thunar.xml.template" ]]; then
        local target_thunar="${USER_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml"
        mkdir -p "$(dirname "$target_thunar")"
        if [[ -f "$target_thunar" && ! -L "$target_thunar" ]]; then
            backup_and_prepare_target "$target_thunar" || return 1
        fi
        sed "s|_USER_HOME_|${USER_HOME}|g" "${ROOT_DIR}/templates/xfce4/thunar.xml.template" > "$target_thunar"
    fi


    log_info "Stowing dotfiles packages into ${USER_HOME}"
    cd "$DOTFILES_DIR"
    stow -t "$USER_HOME" "${PACKAGES[@]}"

    log_success "Dotfiles stow step completed successfully."
}

main "$@"