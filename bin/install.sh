#!/usr/bin/env bash

set -eEuo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${SCRIPT_SOURCE}")" && pwd)"
COMMON_LIB="${SCRIPT_DIR}/lib/common.sh"

if [[ -r "$COMMON_LIB" ]]; then
    # shellcheck disable=SC1090
    source "$COMMON_LIB"
else
    resolve_user_home() {
        local resolved_home
        resolved_home="$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6 || true)"

        if [[ -n "$resolved_home" ]]; then
            printf '%s\n' "$resolved_home"
        else
            printf '%s\n' "${HOME}"
        fi
    }

    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_BLUE=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_RED=""
    COLOR_CYAN=""

    setup_colors() {
        if [[ -z "${NO_COLOR:-}" ]]; then
            COLOR_RESET=$'\033[0m'
            COLOR_BOLD=$'\033[1m'
            COLOR_BLUE=$'\033[34m'
            COLOR_GREEN=$'\033[32m'
            COLOR_YELLOW=$'\033[33m'
            COLOR_RED=$'\033[31m'
            COLOR_CYAN=$'\033[36m'
        fi
    }

    log_phase() {
        printf "\n%s%s==> %s%s\n" "$COLOR_BOLD" "$COLOR_BLUE" "$1" "$COLOR_RESET"
    }

    log_info() {
        printf "%s[INFO]%s %s\n" "$COLOR_CYAN" "$COLOR_RESET" "$1"
    }

    log_success() {
        printf "%s[OK]%s %s\n" "$COLOR_GREEN" "$COLOR_RESET" "$1"
    }

    log_warn() {
        printf "%s[WARN]%s %s\n" "$COLOR_YELLOW" "$COLOR_RESET" "$1"
    }

    log_error() {
        printf "%s[ERROR]%s %s\n" "$COLOR_RED" "$COLOR_RESET" "$1" >&2
    }
fi

HYPRVIBE_REPO_URL="${HYPRVIBE_REPO_URL:-https://github.com/IAmBatMan295/HyprVibe.git}"
USER_HOME="$(resolve_user_home)"
HYPRVIBE_TARGET_DIR="${USER_HOME}/HyprVibe"
MODULES_DIR="$SCRIPT_DIR"
INSTALL_LOG_FILE="${USER_HOME}/hyprvibe-log.txt"
SUDO_KEEPALIVE_PID=""
CLONE_TMP_DIR=""

on_error() {
    local line_no="$1"
    local exit_code="$2"
    log_error "install.sh failed at line ${line_no} with exit code ${exit_code}."
}

trap 'on_error "$LINENO" "$?"' ERR

setup_run_logging() {
    if [[ "${HYPRVIBE_LOGGING_ACTIVE:-0}" == "1" ]]; then
        return 0
    fi

    if ! : >"$INSTALL_LOG_FILE"; then
        log_error "Failed to create log file at ${INSTALL_LOG_FILE}."
        exit 1
    fi

    export HYPRVIBE_LOGGING_ACTIVE=1
    export HYPRVIBE_INSTALL_LOG_FILE="$INSTALL_LOG_FILE"

    if command -v stdbuf >/dev/null 2>&1; then
        exec > >(stdbuf -o0 -e0 tee "$INSTALL_LOG_FILE") 2>&1
    else
        exec > >(tee "$INSTALL_LOG_FILE") 2>&1
    fi

    log_info "Logging installer output to ${INSTALL_LOG_FILE}"
}

require_interactive_tty() {
    if [[ -r /dev/tty ]]; then
        return 0
    fi

    log_error "Interactive terminal input is required for this installer."
    log_warn "Run the script from a normal terminal session."
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
        log_error "Could not determine a safe user home directory."
        exit 1
    fi

    if [[ "$resolved_target" != "${resolved_home}/HyprVibe" ]]; then
        log_error "Installer target is fixed to ${resolved_home}/HyprVibe"
        exit 1
    fi
}

refresh_hyprvibe_clone() {
    validate_target_dir

    if ! command -v git >/dev/null 2>&1; then
        log_error "git is required for bootstrap clone."
        exit 1
    fi

    CLONE_TMP_DIR="$(mktemp -d)" || {
        log_error "Failed to create temporary directory for clone."
        exit 1
    }

    trap 'cleanup_clone_temp; exit 1' INT TERM

    local cloned_repo_dir="${CLONE_TMP_DIR}/HyprVibe"

    log_phase "Bootstrap Repository"
    log_info "Cloning fresh HyprVibe copy from ${HYPRVIBE_REPO_URL}"
    if ! git clone --depth 1 "$HYPRVIBE_REPO_URL" "$cloned_repo_dir"; then
        cleanup_clone_temp
        log_error "Failed to clone ${HYPRVIBE_REPO_URL}"
        exit 1
    fi

    if [[ ! -f "${cloned_repo_dir}/bin/install.sh" ]]; then
        cleanup_clone_temp
        log_error "Cloned repository does not contain bin/install.sh"
        exit 1
    fi

    mkdir -p "$(dirname -- "$HYPRVIBE_TARGET_DIR")"
    cd "$USER_HOME"

    if [[ -e "$HYPRVIBE_TARGET_DIR" ]]; then
        log_warn "Replacing existing directory: ${HYPRVIBE_TARGET_DIR}"
        rm -rf "$HYPRVIBE_TARGET_DIR"
    fi

    mv "$cloned_repo_dir" "$HYPRVIBE_TARGET_DIR"
    cleanup_clone_temp
    trap - INT TERM

    MODULES_DIR="${HYPRVIBE_TARGET_DIR}/bin"

    if [[ ! -f "${MODULES_DIR}/install.sh" ]]; then
        log_error "Missing installer in cloned repo at ${MODULES_DIR}/install.sh"
        exit 1
    fi

    log_success "Using modules from ${MODULES_DIR}"
}

start_sudo_keepalive() {
    log_phase "Sudo Session"
    log_info "Requesting sudo once for this full install run"
    if ! sudo -v; then
        log_error "Failed to validate sudo credentials."
        return 1
    fi

    while true; do
        sleep 50

        if ! kill -0 "$$" 2>/dev/null; then
            exit 0
        fi

        if ! sudo -n true 2>/dev/null; then
            log_error "Sudo session expired during install. Stopping installer."
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
        log_error "Required module not found: $module_path"
        return 1
    fi

    log_phase "Running module: ${module_script}"

    if ! bash "$module_path"; then
        log_error "Module failed: ${module_script}"
        return 1
    fi

    log_success "Module completed: ${module_script}"
}

main() {
    setup_colors
    setup_run_logging

    refresh_hyprvibe_clone "$@"

    if [[ "${EUID}" -eq 0 ]]; then
        log_error "Please run this script as a normal user with sudo privileges, not as root."
        exit 1
    fi

    require_interactive_tty || exit 1

    trap stop_sudo_keepalive EXIT
    start_sudo_keepalive || exit 1

    run_module "github-auth.sh" || exit 1
    run_module "install-packes.sh" || exit 1
    run_module "theme-assets-installer.sh" || exit 1
    run_module "miscellenious.sh" || exit 1

    log_phase "Installer Summary"
    log_success "All install modules completed successfully."
}

main "$@"