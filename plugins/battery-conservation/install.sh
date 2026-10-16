#!/usr/bin/env bash

set -euE -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
COMMON_LIB="${ROOT_DIR}/bin/lib/common.sh"

if [[ -r "$COMMON_LIB" ]]; then
    # shellcheck disable=SC1090
    source "$COMMON_LIB"
fi

PLUGIN_NAME="Lenovo Battery Conservation Mode"

log_info() {
    printf "[INFO] %s\n" "$1"
}

log_success() {
    printf "[OK] %s\n" "$1"
}

log_warn() {
    printf "[WARN] %s\n" "$1"
}

log_error() {
    printf "[ERROR] %s\n" "$1" >&2
}

echo "==> Installing Plugin: ${PLUGIN_NAME}"

# Probe for conservation mode in sysfs
found_path=""
for candidate in \
    "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode" \
    "/sys/devices/platform/ideapad_acpi/VPC2004:00/conservation_mode"; do
    if [[ -f "$candidate" ]]; then
        found_path="$candidate"
        break
    fi
done

if [[ -z "$found_path" ]]; then
    found_path="$(find /sys/devices/ -name "conservation_mode" 2>/dev/null | head -n 1 || true)"
fi

if [[ -n "$found_path" && -f "$found_path" ]]; then
    log_success "Compatible Lenovo hardware detected at: ${found_path}"
    
    # Setup udev rule so user can change conservation mode without sudo password prompt
    udev_rule_file="/etc/udev/rules.d/99-battery-conservation.rules"
    log_info "Creating udev rule for passwordless conservation mode switching at ${udev_rule_file}"
    echo "ACTION==\"add\", SUBSYSTEM==\"platform\", ATTR{conservation_mode}==\"*\", RUN+=\"/bin/chmod 0666 ${found_path}\"" | sudo tee "$udev_rule_file" >/dev/null 2>&1 || true
    sudo chmod 666 "$found_path" 2>/dev/null || true
    
    log_success "${PLUGIN_NAME} plugin configured successfully."
else
    log_warn "No supported Lenovo battery conservation hardware detected on this machine."
    log_info "Plugin registered, but feature will remain inactive until run on supported hardware."
fi
