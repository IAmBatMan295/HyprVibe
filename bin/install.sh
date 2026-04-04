#!/usr/bin/env bash

set -uE -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HYPRVIBE_REPO_URL="${HYPRVIBE_REPO_URL:-https://github.com/IAmBatMan295/HyprVibe.git}"
HYPRVIBE_TARGET_DIR="${HYPRVIBE_TARGET_DIR:-${HOME}/HyprVibe}"
MODULES_DIR="$SCRIPT_DIR"
SUDO_KEEPALIVE_PID=""

refresh_hyprvibe_clone() {
    if [[ -z "${HYPRVIBE_TARGET_DIR}" || "${HYPRVIBE_TARGET_DIR}" == "/" ]]; then
        echo "Error: Unsafe HYPRVIBE_TARGET_DIR value: ${HYPRVIBE_TARGET_DIR}"
        exit 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        echo "Error: git is required for bootstrap clone."
        exit 1
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)" || {
        echo "Error: Failed to create temporary directory for clone."
        exit 1
    }

    local cloned_repo_dir="${tmp_dir}/HyprVibe"

    echo "==> Cloning fresh HyprVibe copy from ${HYPRVIBE_REPO_URL}"
    if ! git clone "$HYPRVIBE_REPO_URL" "$cloned_repo_dir"; then
        rm -rf "$tmp_dir"
        echo "Error: Failed to clone ${HYPRVIBE_REPO_URL}"
        exit 1
    fi

    if [[ ! -f "${cloned_repo_dir}/bin/install.sh" ]]; then
        rm -rf "$tmp_dir"
        echo "Error: Cloned repository does not contain bin/install.sh"
        exit 1
    fi

    mkdir -p "$(dirname -- "$HYPRVIBE_TARGET_DIR")"
    cd "$HOME"

    if [[ -e "$HYPRVIBE_TARGET_DIR" ]]; then
        echo "==> Replacing existing directory: ${HYPRVIBE_TARGET_DIR}"
        rm -rf "$HYPRVIBE_TARGET_DIR"
    fi

    mv "$cloned_repo_dir" "$HYPRVIBE_TARGET_DIR"
    rm -rf "$tmp_dir"

    MODULES_DIR="${HYPRVIBE_TARGET_DIR}/bin"

    if [[ ! -f "${MODULES_DIR}/install.sh" ]]; then
        echo "Error: Missing installer in cloned repo at ${MODULES_DIR}/install.sh"
        exit 1
    fi

    echo "==> Using modules from ${MODULES_DIR}"
}

start_sudo_keepalive() {
    echo "==> Requesting sudo once for this full install run"
    sudo -v

    while true; do
        if ! sudo -n true 2>/dev/null; then
            exit 1
        fi
        sleep 50
        kill -0 "$$" 2>/dev/null || exit 0
    done &

    SUDO_KEEPALIVE_PID="$!"
}

stop_sudo_keepalive() {
    if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
        kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
    fi
    sudo -k
}

run_module() {
    local module_script="$1"
    local module_path="${MODULES_DIR}/${module_script}"

    if [[ ! -f "$module_path" ]]; then
        echo "Error: Required module not found: $module_path"
        return 1
    fi

    echo ""
    echo "==> Running module: ${module_script}"

    if ! bash "$module_path"; then
        echo "Error: Module failed: ${module_script}"
        return 1
    fi

    echo "==> Module completed: ${module_script}"
}

main() {
    refresh_hyprvibe_clone "$@"

    if [[ "${EUID}" -eq 0 ]]; then
        echo "Please run this script as a normal user with sudo privileges, not as root."
        exit 1
    fi

    trap stop_sudo_keepalive EXIT
    start_sudo_keepalive

    run_module "github-auth.sh" || exit 1
    run_module "install-packes.sh" || exit 1
    run_module "theme-assets-installer.sh" || exit 1
    run_module "stow-dotfiles.sh" || exit 1

    echo ""
    echo "All install modules completed successfully."
}

main "$@"