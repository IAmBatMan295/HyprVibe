#!/usr/bin/env bash

set -uE -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SUDO_KEEPALIVE_PID=""

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
    local module_path="${SCRIPT_DIR}/${module_script}"

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
    if [[ "${EUID}" -eq 0 ]]; then
        echo "Please run this script as a normal user with sudo privileges, not as root."
        exit 1
    fi

    trap stop_sudo_keepalive EXIT
    start_sudo_keepalive

    run_module "github-auth.sh" || exit 1
    run_module "install-packes.sh" || exit 1

    echo ""
    echo "All install modules completed successfully."
}

main "$@"