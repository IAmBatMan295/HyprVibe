#!/usr/bin/env bash

# Shared installer helpers for consistent output and interaction.

COLOR_RESET=""
COLOR_BOLD=""
COLOR_BLUE=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_RED=""
COLOR_CYAN=""

resolve_user_home() {
    local resolved_home
    resolved_home="$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6 || true)"

    if [[ -n "$resolved_home" ]]; then
        printf '%s\n' "$resolved_home"
    else
        printf '%s\n' "${HOME}"
    fi
}

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
    local min_attempts="${MIN_ATTEMPTS:-3}"
    local next_attempt=$((attempt + 1))
    local answer

    while true; do
        if ! read_from_tty "$step_name failed on attempt ${attempt}. Retry with attempt ${next_attempt}? [y/N]: " answer; then
            log_error "Interactive input unavailable. Cannot continue retry loop for ${step_name}."
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
                log_warn "Please answer yes or no."
                ;;
        esac
    done
}

run_with_retries() {
    local step_name="$1"
    local command_fn="$2"
    local verify_fn="$3"
    local min_attempts="${MIN_ATTEMPTS:-3}"
    local attempt=1

    while true; do
        log_phase "${step_name}: attempt ${attempt}"

        if "$command_fn" && "$verify_fn"; then
            log_success "${step_name}: success"
            return 0
        fi

        if (( attempt < min_attempts )); then
            log_warn "${step_name}: failed (minimum target is ${min_attempts} attempts)"
        else
            log_warn "${step_name}: failed after ${attempt} attempt(s)"
        fi

        if ! prompt_retry "$attempt" "$step_name"; then
            log_error "Aborted by user during ${step_name}."
            return 1
        fi

        ((attempt++))
    done
}
