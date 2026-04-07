#!/usr/bin/env bash

set -uE -o pipefail

MIN_ATTEMPTS=3
USER_HOME="$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6 || true)"
if [[ -z "$USER_HOME" ]]; then
    USER_HOME="${HOME}"
fi
ICONS_DIR="${USER_HOME}/.local/share/icons"
YAMIS_DIR_USER="${ICONS_DIR}/YAMIS"
YAMIS_DIR_SYSTEM="/usr/share/icons/YAMIS"

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
            echo "==> YAMIS already installed at ${existing_path}. Skipping clone/install."
        else
            echo "==> YAMIS already installed. Skipping clone/install."
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
        echo "==> Trying YAMIS source: ${url}"
        if git clone --depth 1 "$url" "${tmp_dir}/src" >/dev/null 2>&1; then
            cloned_dir="${tmp_dir}/src"
            break
        fi
    done

    if [[ -z "$cloned_dir" ]]; then
        echo "Error: Unable to clone YAMIS from configured sources."
        rm -rf "$tmp_dir"
        return 1
    fi

    local theme_dir
    if ! theme_dir="$(detect_theme_dir "$cloned_dir")"; then
        local extracted_dir="${tmp_dir}/extracted"
        if ! theme_dir="$(try_extract_archive_theme_dir "$cloned_dir" "$extracted_dir")"; then
            echo "Error: Could not find YAMIS theme files in cloned repository."
            rm -rf "$tmp_dir"
            return 1
        fi
    fi

    echo "==> Using YAMIS theme files from: ${theme_dir}"

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
        echo "Error: YAMIS install verification failed: missing ${YAMIS_DIR_USER}/index.theme"
        rm -rf "$tmp_dir"
        return 1
    fi

    echo "==> YAMIS installed to ${YAMIS_DIR_USER}"

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
    run_with_retries "Install YAMIS icon theme" install_yamis_once verify_yamis_install || exit 1
    echo ""
    echo "Theme assets installation completed successfully."
}

main "$@"