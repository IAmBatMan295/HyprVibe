#!/usr/bin/env bash

set -uE -o pipefail

MIN_ATTEMPTS=3
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="${SCRIPT_DIR}/lib/common.sh"

if [[ ! -r "$COMMON_LIB" ]]; then
    echo "Error: Missing common helper library: $COMMON_LIB" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$COMMON_LIB"

USER_HOME="$(resolve_user_home)"
ICONS_DIR="${USER_HOME}/.local/share/icons"
YAMIS_DIR_USER="${ICONS_DIR}/YAMIS"
YAMIS_DIR_SYSTEM="/usr/share/icons/YAMIS"

yamis_installed() {
    [[ -f "${YAMIS_DIR_USER}/index.theme" || -f "${YAMIS_DIR_SYSTEM}/index.theme" ]]
}

current_yamis_location() {
    if [[ -f "${YAMIS_DIR_USER}/index.theme" ]]; then
        printf '%s\n' "${YAMIS_DIR_USER}"
        return 0
    fi

    if [[ -f "${YAMIS_DIR_SYSTEM}/index.theme" ]]; then
        printf '%s\n' "${YAMIS_DIR_SYSTEM}"
        return 0
    fi

    return 1
}

detect_theme_dir() {
    local repo_dir="$1"

    if [[ -f "${repo_dir}/index.theme" ]]; then
        printf '%s\n' "$repo_dir"
        return 0
    fi

    local candidate
    candidate="$(find "$repo_dir" -maxdepth 6 -type f -name index.theme | head -n 1 || true)"
    if [[ -n "$candidate" ]]; then
        dirname "$candidate"
        return 0
    fi

    return 1
}

try_extract_archive_theme_dir() {
    local source_dir="$1"
    local unpack_dir="$2"

    local archive_file
    archive_file="$(find "$source_dir" -maxdepth 3 -type f \( -name '*.tar.gz' -o -name '*.tgz' -o -name '*.tar.xz' -o -name '*.tar.zst' \) | head -n 1 || true)"
    if [[ -z "$archive_file" ]]; then
        return 1
    fi

    mkdir -p "$unpack_dir" || return 1
    if ! tar -xf "$archive_file" -C "$unpack_dir"; then
        return 1
    fi

    detect_theme_dir "$unpack_dir"
}

install_yamis_once() {
    if yamis_installed; then
        local existing_path
        existing_path="$(current_yamis_location || true)"
        if [[ -n "$existing_path" ]]; then
            log_success "YAMIS already installed at ${existing_path}. Skipping clone/install."
        else
            log_success "YAMIS already installed. Skipping clone/install."
        fi
        return 0
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)" || return 1

    local -a repo_urls=()
    if [[ -n "${YAMIS_REPO_URL:-}" ]]; then
        repo_urls+=("${YAMIS_REPO_URL}")
    fi

    repo_urls+=(
        "https://github.com/googIyEYES/YAMIS.git"
        "https://bitbucket.org/dirn-typo/yet-another-monochrome-icon-set.git"
    )

    local url
    local cloned_dir=""
    for url in "${repo_urls[@]}"; do
        log_info "Trying YAMIS source: ${url}"
        if git clone --depth 1 "$url" "${tmp_dir}/src" >/dev/null 2>&1; then
            cloned_dir="${tmp_dir}/src"
            break
        fi
    done

    if [[ -z "$cloned_dir" ]]; then
        log_error "Unable to clone YAMIS from configured sources."
        rm -rf "$tmp_dir"
        return 1
    fi

    local theme_dir
    if ! theme_dir="$(detect_theme_dir "$cloned_dir")"; then
        local extracted_dir="${tmp_dir}/extracted"
        if ! theme_dir="$(try_extract_archive_theme_dir "$cloned_dir" "$extracted_dir")"; then
            log_error "Could not find YAMIS theme files in cloned repository."
            rm -rf "$tmp_dir"
            return 1
        fi
    fi

    log_info "Using YAMIS theme files from: ${theme_dir}"

    mkdir -p "$ICONS_DIR" || {
        rm -rf "$tmp_dir"
        return 1
    }

    rm -rf "$YAMIS_DIR_USER"
    mkdir -p "$YAMIS_DIR_USER" || {
        rm -rf "$tmp_dir"
        return 1
    }

    cp -a "${theme_dir}/." "$YAMIS_DIR_USER" || {
        rm -rf "$tmp_dir"
        return 1
    }

    if [[ ! -f "${YAMIS_DIR_USER}/index.theme" ]]; then
        log_error "YAMIS install verification failed: missing ${YAMIS_DIR_USER}/index.theme"
        rm -rf "$tmp_dir"
        return 1
    fi

    log_success "YAMIS installed to ${YAMIS_DIR_USER}"

    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$YAMIS_DIR_USER" >/dev/null 2>&1 || true
    fi

    rm -rf "$tmp_dir"
    return 0
}

verify_yamis_install() {
    yamis_installed
}

main() {
    setup_colors

    run_with_retries "Install YAMIS icon theme" install_yamis_once verify_yamis_install || exit 1
    log_phase "Theme Assets Summary"
    log_success "Theme assets installation completed successfully."
}

main "$@"