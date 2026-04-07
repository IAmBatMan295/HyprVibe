#!/usr/bin/env bash

set -eEuo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${SCRIPT_SOURCE}")" && pwd)"
HYPRVIBE_REPO_URL="${HYPRVIBE_REPO_URL:-https://github.com/IAmBatMan295/HyprVibe.git}"
USER_HOME="$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6 || true)"
if [[ -z "$USER_HOME" ]]; then
    USER_HOME="${HOME}"
fi
HYPRVIBE_TARGET_DIR="${USER_HOME}/HyprVibe"
MODULES_DIR="$SCRIPT_DIR"
INSTALL_LOG_FILE="${USER_HOME}/hyprvibe-log.txt"
SUDO_KEEPALIVE_PID=""
CLONE_TMP_DIR=""

on_error() {
    local line_no="$1"
    local exit_code="$2"
    echo "Error: install.sh failed at line ${line_no} with exit code ${exit_code}."
}

trap 'on_error "$LINENO" "$?"' ERR

setup_run_logging() {
    if [[ "${HYPRVIBE_LOGGING_ACTIVE:-0}" == "1" ]]; then
        return 0
    fi

    if ! : >"$INSTALL_LOG_FILE"; then
        echo "Error: Failed to create log file at ${INSTALL_LOG_FILE}."
        exit 1
    fi

    export HYPRVIBE_LOGGING_ACTIVE=1
    export HYPRVIBE_INSTALL_LOG_FILE="$INSTALL_LOG_FILE"

    if command -v stdbuf >/dev/null 2>&1; then
        exec > >(stdbuf -o0 -e0 tee "$INSTALL_LOG_FILE") 2>&1
    else
        exec > >(tee "$INSTALL_LOG_FILE") 2>&1
    fi

    echo "==> Logging installer output to ${INSTALL_LOG_FILE}"
}

require_interactive_tty() {
    if [[ -r /dev/tty ]]; then
        return 0
    fi

    echo "Error: Interactive terminal input is required for this installer."
    echo "Run the script from a normal terminal session."
    return 1
}

cleanup_clone_temp() {
    if [[ -n "$CLONE_TMP_DIR" && -d "$CLONE_TMP_DIR" ]]; then
        rm -rf "$CLONE_TMP_DIR"
    fi
}

validate_target_dir() {
    local resolved_home
    local resolved_target

    resolved_home="$(realpath -m "$USER_HOME")"
    resolved_target="$(realpath -m "$HYPRVIBE_TARGET_DIR")"

    if [[ -z "$resolved_home" || "$resolved_home" == "/" ]]; then
        echo "Error: Could not determine a safe user home directory."
        exit 1
    fi

    if [[ "$resolved_target" != "${resolved_home}/HyprVibe" ]]; then
        echo "Error: Installer target is fixed to ${resolved_home}/HyprVibe"
        exit 1
    fi
}

refresh_hyprvibe_clone() {
    validate_target_dir

    if ! command -v git >/dev/null 2>&1; then
        echo "Error: git is required for bootstrap clone."
        exit 1
    fi

    CLONE_TMP_DIR="$(mktemp -d)" || {
        echo "Error: Failed to create temporary directory for clone."
        exit 1
    }

    trap 'cleanup_clone_temp; exit 1' INT TERM

    local cloned_repo_dir="${CLONE_TMP_DIR}/HyprVibe"

    echo "==> Cloning fresh HyprVibe copy from ${HYPRVIBE_REPO_URL}"
    if ! git clone --depth 1 "$HYPRVIBE_REPO_URL" "$cloned_repo_dir"; then
        cleanup_clone_temp
        echo "Error: Failed to clone ${HYPRVIBE_REPO_URL}"
        exit 1
    fi

    if [[ ! -f "${cloned_repo_dir}/bin/install.sh" ]]; then
        cleanup_clone_temp
        echo "Error: Cloned repository does not contain bin/install.sh"
        exit 1
    fi

    mkdir -p "$(dirname -- "$HYPRVIBE_TARGET_DIR")"
    cd "$USER_HOME"

    if [[ -e "$HYPRVIBE_TARGET_DIR" ]]; then
        echo "==> Replacing existing directory: ${HYPRVIBE_TARGET_DIR}"
        rm -rf "$HYPRVIBE_TARGET_DIR"
    fi

    mv "$cloned_repo_dir" "$HYPRVIBE_TARGET_DIR"
    cleanup_clone_temp
    trap - INT TERM

    MODULES_DIR="${HYPRVIBE_TARGET_DIR}/bin"

    if [[ ! -f "${MODULES_DIR}/install.sh" ]]; then
        echo "Error: Missing installer in cloned repo at ${MODULES_DIR}/install.sh"
        exit 1
    fi

    echo "==> Using modules from ${MODULES_DIR}"
}

start_sudo_keepalive() {
    echo "==> Requesting sudo once for this full install run"
    if ! sudo -v; then
        echo "Error: Failed to validate sudo credentials."
        return 1
    fi

    while true; do
        sleep 50

        if ! kill -0 "$$" 2>/dev/null; then
            exit 0
        fi

        if ! sudo -n true 2>/dev/null; then
            echo "Error: Sudo session expired during install. Stopping installer."
            kill -TERM "$$" >/dev/null 2>&1 || true
            exit 1
        fi
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
    setup_run_logging

    refresh_hyprvibe_clone "$@"

    if [[ "${EUID}" -eq 0 ]]; then
        echo "Please run this script as a normal user with sudo privileges, not as root."
        exit 1
    fi

    require_interactive_tty || exit 1

    trap stop_sudo_keepalive EXIT
    start_sudo_keepalive || exit 1

    run_module "github-auth.sh" || exit 1
    run_module "install-packes.sh" || exit 1
    run_module "theme-assets-installer.sh" || exit 1
    run_module "stow-dotfiles.sh" || exit 1
    run_module "miscellenious.sh" || exit 1

    echo ""
    echo "All install modules completed successfully."
}

main "$@"