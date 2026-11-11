#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Title: Local LLM Server
# Description: Helper script to manage and launch llama-server with local models
# ==============================================================================

HELPER_TITLE="Local LLM Server"
HELPER_ICON="󰧑"
HELPER_ORDER=22

# ------------------------------------------------------------------------------
# Floating Window Spawn Logic (45% screen width x 48% height, centered)
# ------------------------------------------------------------------------------
IS_INNER=false
for a in "$@"; do
    case "$a" in
        --inner|--headless|--status|--dry-run-cmd|--list-models|--start|--stop|--restart)
            IS_INNER=true
            ;;
    esac
done

if [[ "$IS_INNER" == "false" ]]; then
    SCRIPT_FILE=$(readlink -f "$0")

    MON_INFO=$(hyprctl monitors -j 2>/dev/null || true)
    WIDTH=$(echo "$MON_INFO" | jq -r '.[] | select(.focused == true) | .width // empty' 2>/dev/null || true)
    if [[ -z "$WIDTH" ]]; then
        WIDTH=$(echo "$MON_INFO" | jq -r '.[0].width // 1920' 2>/dev/null || true)
        HEIGHT=$(echo "$MON_INFO" | jq -r '.[0].height // 1080' 2>/dev/null || true)
        SCALE=$(echo "$MON_INFO" | jq -r '.[0].scale // 1.0' 2>/dev/null || true)
    else
        HEIGHT=$(echo "$MON_INFO" | jq -r '.[] | select(.focused == true) | .height // 1080' 2>/dev/null || true)
        SCALE=$(echo "$MON_INFO" | jq -r '.[] | select(.focused == true) | .scale // 1.0' 2>/dev/null || true)
    fi

    TARGET_W=$(awk -v w="$WIDTH" -v s="$SCALE" 'BEGIN { printf "%d", (w / s) * 0.45 }')
    TARGET_H=$(awk -v h="$HEIGHT" -v s="$SCALE" 'BEGIN { printf "%d", (h / s) * 0.48 }')
    [[ "$TARGET_W" -lt 640 ]] && TARGET_W=640
    [[ "$TARGET_H" -lt 400 ]] && TARGET_H=400

    if command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1; then
        hyprctl eval "hl.window_rule({ match = { class = 'llama-server-helper' }, float = true, center = true, size = '${TARGET_W} ${TARGET_H}' })" >/dev/null 2>&1 || true
        hyprctl eval "hl.exec_cmd('foot -a llama-server-helper -T \"${HELPER_TITLE}\" -w ${TARGET_W}x${TARGET_H} bash \"${SCRIPT_FILE}\" --inner \"$@\"')" >/dev/null 2>&1 || true
        exit 0
    fi
fi

# ------------------------------------------------------------------------------
# State & Configuration Paths
# ------------------------------------------------------------------------------
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/llama-server"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/llama-server"
CONFIG_FILE="${CONFIG_DIR}/llama-server.conf"
PID_FILE="${STATE_DIR}/llama-server.pid"
LOG_FILE="${HOME}/llama-server.log"
CURRENT_INFO_FILE="${STATE_DIR}/llama-server.current"

mkdir -p "$STATE_DIR" "$CONFIG_DIR"

MODELS_DIR="${HOME}/models"
GPU_LAYERS=99
CTX_SIZE=65536
CTK="q8_0"
CTV="q8_0"
FLASH_ATTN="on"
PORT=8080
HOST="127.0.0.1"
LAST_MODEL=""

# Load persisted configuration if available
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# Model Discovery & Heuristics
# ------------------------------------------------------------------------------
find_models() {
    local target_dir="${1:-$MODELS_DIR}"
    if [[ ! -d "$target_dir" ]]; then
        return 0
    fi
    find "$target_dir" -maxdepth 2 -type f -name "*.gguf" 2>/dev/null | sort
}

detect_smart_context() {
    local model_path="$1"
    local filename
    filename="$(basename "$model_path" | tr '[:upper:]' '[:lower:]')"

    # Check for known context profiles or model families
    # Hermes Agent requires >= 64,000 tokens context. Qwen2.5 natively supports up to 128k.
    if [[ "$filename" == *"qwen2.5"* ]]; then
        echo "65536"
    elif [[ "$filename" == *"64k"* ]]; then
        echo "65536"
    elif [[ "$filename" == *"32k"* ]]; then
        echo "32768"
    elif [[ "$filename" == *"16k"* ]]; then
        echo "16384"
    elif [[ "$filename" == *"8k"* ]]; then
        echo "8192"
    elif [[ "$filename" == *"deepseek"* ]]; then
        echo "65536"
    elif [[ "$filename" == *"mistral"* ]]; then
        echo "32768"
    elif [[ "$filename" == *"llama-3"* || "$filename" == *"llama3"* ]]; then
        echo "8192"
    else
        # Default modern standard context token limit (Hermes compatible)
        echo "65536"
    fi
}

get_model_alias() {
    local model_path="$1"
    local base lower_base
    base=$(basename "$model_path" .gguf)
    lower_base="$(echo "$base" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower_base" == *"qwen2.5-coder-7b"* ]]; then
        echo "qwen2.5-coder-7b,${base}"
    elif [[ "$lower_base" == *"mistral"* ]]; then
        echo "mistral,${base}"
    elif [[ "$lower_base" == *"deepseek"* ]]; then
        echo "deepseek,${base}"
    else
        echo "${base}"
    fi
}

save_config() {
    local rel_models="${MODELS_DIR/#$HOME/\${HOME\}}"
    local rel_last="${LAST_MODEL/#$HOME/\${HOME\}}"
    cat > "$CONFIG_FILE" <<EOF
# Configuration for Local LLM Server Helper
# Managed via HyprVibe dotfiles (GNU Stow)

MODELS_DIR="${rel_models}"
GPU_LAYERS=${GPU_LAYERS}
CTX_SIZE=${CTX_SIZE}
CTK="${CTK}"
CTV="${CTV}"
FLASH_ATTN="${FLASH_ATTN}"
PORT=${PORT}
HOST="${HOST}"
LAST_MODEL="${rel_last}"
EOF
}

# ------------------------------------------------------------------------------
# Process Status & Control
# ------------------------------------------------------------------------------
get_server_pid() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        fi
    fi

    # Fallback process search
    local proc_pid
    proc_pid=$(pgrep -x llama-server 2>/dev/null | head -n 1 || true)
    if [[ -n "$proc_pid" ]]; then
        echo "$proc_pid"
        return 0
    fi
    return 1
}

is_running() {
    get_server_pid >/dev/null 2>&1
}

build_cmd_args() {
    local model="$1"
    local ctx="${2:-$CTX_SIZE}"
    local layers="${3:-$GPU_LAYERS}"
    local port="${4:-$PORT}"
    local host="${5:-$HOST}"
    local alias
    alias=$(get_model_alias "$model")

    echo "llama-server -m \"$model\" -ngl $layers -c $ctx -ctk $CTK -ctv $CTV -fa $FLASH_ATTN --jinja --port $port --host $host -a $alias"
}

start_server() {
    local model="$1"
    local ctx="${2:-$CTX_SIZE}"
    local layers="${3:-$GPU_LAYERS}"
    local port="${4:-$PORT}"
    local host="${5:-$HOST}"
    local alias
    alias=$(get_model_alias "$model")

    if is_running; then
        echo "  Server already running (PID: $(get_server_pid)). Stop or restart first."
        return 1
    fi

    if [[ ! -f "$model" ]]; then
        echo "  Error: Model file does not exist: $model"
        return 1
    fi

    echo "  Starting llama-server..."
    echo "  Model:   $(basename "$model") (Alias: $alias)"
    echo "  Context: $ctx | GPU Layers: $layers | KV: $CTK/$CTV"
    echo "  Listen:  http://${host}:${port}"

    # Launch daemon in background with setsid to detach from session process group
    # shellcheck disable=SC2086
    setsid -f llama-server \
        -m "$model" \
        -ngl "$layers" \
        -c "$ctx" \
        -ctk "$CTK" \
        -ctv "$CTV" \
        -fa "$FLASH_ATTN" \
        --jinja \
        --port "$port" \
        --host "$host" \
        -a "$alias" >> "$LOG_FILE" 2>&1 < /dev/null
    
    local pid=""
    for _ in {1..20}; do
        pid=$(pgrep -x llama-server 2>/dev/null | head -n 1 || true)
        if [[ -n "$pid" ]]; then
            break
        fi
        sleep 0.1
    done

    if [[ -z "$pid" ]]; then
        echo "  ❌ Failed to launch llama-server process."
        tail -n 10 "$LOG_FILE"
        return 1
    fi

    echo "$pid" > "$PID_FILE"
    cat > "$CURRENT_INFO_FILE" <<EOF
MODEL="$model"
CTX=$ctx
LAYERS=$layers
PORT=$port
HOST=$host
START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
EOF

    LAST_MODEL="$model"
    CTX_SIZE="$ctx"
    save_config

    # Wait up to 6 seconds to confirm healthy startup & port binding
    local started=false
    for _ in {1..15}; do
        if kill -0 "$pid" 2>/dev/null; then
            if curl -s "http://${host}:${port}/props" >/dev/null 2>&1; then
                started=true
                break
            fi
            sleep 0.4
        else
            break
        fi
    done

    if [[ "$started" == "true" ]] || kill -0 "$pid" 2>/dev/null; then
        echo "  ✔ Server successfully started (PID: $pid)"
        command -v notify-send >/dev/null 2>&1 && \
            notify-send -a "${HELPER_TITLE}" "${HELPER_TITLE}" "Server running at http://${host}:${port}" || true
        return 0
    else
        echo "  ❌ Server failed to start. Last log lines:"
        tail -n 10 "$LOG_FILE"
        rm -f "$PID_FILE" "$CURRENT_INFO_FILE"
        return 1
    fi
}

stop_server() {
    local pid
    pid=$(get_server_pid || true)
    if [[ -z "$pid" ]]; then
        echo "  Server is not running."
        rm -f "$PID_FILE" "$CURRENT_INFO_FILE"
        return 0
    fi

    echo "  Stopping llama-server (PID: $pid)..."
    kill "$pid" 2>/dev/null || true

    # Wait up to 5 seconds for clean exit
    local count=0
    while kill -0 "$pid" 2>/dev/null && (( count < 10 )); do
        sleep 0.5
        ((count++)) || true
    done

    if kill -0 "$pid" 2>/dev/null; then
        echo "  Forcing shutdown (SIGKILL)..."
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE" "$CURRENT_INFO_FILE"
    echo "  ✔ Server stopped."
    command -v notify-send >/dev/null 2>&1 && \
        notify-send -a "${HELPER_TITLE}" "${HELPER_TITLE}" "Server stopped" || true
}

# ------------------------------------------------------------------------------
# Headless & CLI Argument Handling (Test & Automation Friendly)
# ------------------------------------------------------------------------------
ACTION=""
TARGET_MODEL_ARG=""
TARGET_MODELS_DIR_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --status)
            ACTION="status"
            shift
            ;;
        --list-models)
            ACTION="list-models"
            shift
            ;;
        --models-dir)
            MODELS_DIR="$2"
            TARGET_MODELS_DIR_ARG="$2"
            shift 2
            ;;
        --model)
            TARGET_MODEL_ARG="$2"
            shift 2
            ;;
        --dry-run-cmd)
            ACTION="dry-run-cmd"
            shift
            ;;
        --start)
            ACTION="start"
            shift
            ;;
        --stop)
            ACTION="stop"
            shift
            ;;
        --restart)
            ACTION="restart"
            shift
            ;;
        --inner)
            ACTION="inner"
            shift
            break
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -n "$ACTION" && "$ACTION" != "inner" ]]; then
    case "$ACTION" in
        status)
            if is_running; then
                echo "running"
                exit 0
            else
                echo "stopped"
                exit 0
            fi
            ;;
        list-models)
            dir="${TARGET_MODELS_DIR_ARG:-$MODELS_DIR}"
            find_models "$dir"
            exit 0
            ;;
        dry-run-cmd)
            model_to_use="${TARGET_MODEL_ARG:-$LAST_MODEL}"
            if [[ -z "$model_to_use" ]]; then
                mapfile -t found < <(find_models "$MODELS_DIR")
                if (( ${#found[@]} > 0 )); then
                    model_to_use="${found[0]}"
                else
                    model_to_use="${MODELS_DIR}/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf"
                fi
            fi
            ctx_to_use=$(detect_smart_context "$model_to_use")
            build_cmd_args "$model_to_use" "$ctx_to_use" "$GPU_LAYERS" "$PORT" "$HOST"
            exit 0
            ;;
        start)
            model_to_use="${TARGET_MODEL_ARG:-$LAST_MODEL}"
            if [[ -z "$model_to_use" ]]; then
                mapfile -t found < <(find_models "$MODELS_DIR")
                if (( ${#found[@]} > 0 )); then
                    model_to_use="${found[0]}"
                fi
            fi
            if [[ -z "$model_to_use" ]]; then
                echo "Error: No model available to start." >&2
                exit 1
            fi
            start_server "$model_to_use"
            exit $?
            ;;
        stop)
            stop_server
            exit 0
            ;;
        restart)
            stop_server
            model_to_use="${TARGET_MODEL_ARG:-$LAST_MODEL}"
            start_server "$model_to_use"
            exit $?
            ;;
    esac
fi

# ------------------------------------------------------------------------------
# UI Helpers
# ------------------------------------------------------------------------------
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_GREEN="\033[32m"
CLR_RED="\033[31m"
CLR_YELLOW="\033[33m"
CLR_CYAN="\033[36m"
CLR_GRAY="\033[90m"

print_header() {
    clear
    echo ""
    echo -e "  ${CLR_BOLD}${CLR_CYAN}${HELPER_ICON}  ${HELPER_TITLE}${CLR_RESET}"
    echo -e "  ${CLR_GRAY}──────────────────────────────────────────────────${CLR_RESET}"

    if is_running; then
        local pid
        pid=$(get_server_pid || true)
        local cur_model="Unknown"
        local cur_ctx="$CTX_SIZE"
        local cur_port="$PORT"
        local cur_host="$HOST"
        if [[ -f "$CURRENT_INFO_FILE" ]]; then
            # shellcheck disable=SC1090
            source "$CURRENT_INFO_FILE" 2>/dev/null || true
            cur_model="$(basename "${MODEL:-Unknown}")"
            cur_ctx="${CTX:-$CTX_SIZE}"
            cur_port="${PORT:-$PORT}"
            cur_host="${HOST:-$HOST}"
        fi
        echo -e "  Status:  ${CLR_GREEN}${CLR_BOLD}● RUNNING${CLR_RESET} (PID: ${pid})"
        echo -e "  Model:   ${cur_model}"
        echo -e "  Context: ${cur_ctx} tokens (KV: ${CTK} / Flash-Attn: ${FLASH_ATTN})"
        echo -e "  Endpoint: ${CLR_CYAN}http://${cur_host}:${cur_port}${CLR_RESET}"
    else
        echo -e "  Status:  ${CLR_RED}○ STOPPED${CLR_RESET}"
        mapfile -t avail_models < <(find_models "$MODELS_DIR")
        echo -e "  Models:  ${#avail_models[@]} detected in ${MODELS_DIR}"
        if [[ -n "$LAST_MODEL" && -f "$LAST_MODEL" ]]; then
            echo -e "  Default: $(basename "$LAST_MODEL")"
        fi
        echo -e "  Config:  Context: ${CTX_SIZE} | GPU: ${GPU_LAYERS} layers | Port: ${PORT}"
    fi
    echo -e "  ${CLR_GRAY}──────────────────────────────────────────────────${CLR_RESET}"
    echo ""
}

select_model_menu() {
    mapfile -t models < <(find_models "$MODELS_DIR")
    if (( ${#models[@]} == 0 )); then
        echo -e "  ${CLR_YELLOW}No .gguf models found in ${MODELS_DIR}${CLR_RESET}"
        echo "  Please place your .gguf model files into ~/models/"
        read -rp "  Press Enter to continue..."
        return 1
    fi

    echo "  Available Models:"
    for i in "${!models[@]}"; do
        num=$((i + 1))
        mpath="${models[$i]}"
        mname=$(basename "$mpath")
        msize=$(du -h "$mpath" | cut -f1)
        if [[ "$mpath" == "$LAST_MODEL" ]]; then
            echo -e "    ${CLR_GREEN}${num}) ${mname} (${msize}) [default]${CLR_RESET}"
        else
            echo "    ${num}) ${mname} (${msize})"
        fi
    done
    echo "    b) Back"
    echo ""
    read -rp "  Select model [1-${#models[@]}]: " choice

    if [[ "$choice" =~ ^[bB]$ ]]; then
        return 1
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#models[@]} )); then
        local idx=$((choice - 1))
        CHOSEN_MODEL="${models[$idx]}"
        LAST_MODEL="$CHOSEN_MODEL"
        CTX_SIZE=$(detect_smart_context "$CHOSEN_MODEL")
        save_config
        return 0
    else
        echo "  Invalid selection."
        sleep 1
        return 1
    fi
}

settings_menu() {
    while true; do
        print_header
        echo "  Configuration & Parameters:"
        echo "    1) Context Size:     ${CTX_SIZE} tokens"
        echo "    2) GPU Offload:      ${GPU_LAYERS} layers"
        echo "    3) Port:             ${PORT}"
        echo "    4) Models Directory: ${MODELS_DIR}"
        echo "    5) Flash Attention:  ${FLASH_ATTN}"
        echo "    6) KV Quantization:  Key: ${CTK} / Value: ${CTV}"
        echo "    b) Back to Main Menu"
        echo ""
        read -rp "  Change option [1-6, b]: " s_choice
        case "$s_choice" in
            1)
                echo ""
                echo "  Preset Context Sizes:"
                echo "    1) 65536 (64K - Hermes Agent / Qwen2.5 standard)"
                echo "    2) 32768 (32K - Standard)"
                echo "    3) 16384 (16K - Balanced VRAM)"
                echo "    4) 8192  (8K - Low Memory)"
                echo "    5) Custom value"
                read -rp "  Choice [1-5]: " c_choice
                case "$c_choice" in
                    1) CTX_SIZE=65536 ;;
                    2) CTX_SIZE=32768 ;;
                    3) CTX_SIZE=16384 ;;
                    4) CTX_SIZE=8192 ;;
                    5)
                        read -rp "  Enter custom context size (e.g. 65536): " cust
                        [[ "$cust" =~ ^[0-9]+$ ]] && CTX_SIZE="$cust"
                        ;;
                esac
                save_config
                ;;
            2)
                read -rp "  GPU layers to offload [default 99 = all]: " n_layers
                [[ "$n_layers" =~ ^[0-9]+$ ]] && GPU_LAYERS="$n_layers"
                save_config
                ;;
            3)
                read -rp "  Server Port [default 8080]: " n_port
                [[ "$n_port" =~ ^[0-9]+$ ]] && PORT="$n_port"
                save_config
                ;;
            4)
                read -rp "  Models directory path: " n_dir
                [[ -d "$n_dir" ]] && MODELS_DIR="$n_dir"
                save_config
                ;;
            5)
                if [[ "$FLASH_ATTN" == "on" ]]; then
                    FLASH_ATTN="off"
                else
                    FLASH_ATTN="on"
                fi
                save_config
                ;;
            6)
                if [[ "$CTK" == "q8_0" ]]; then
                    CTK="f16"
                    CTV="f16"
                else
                    CTK="q8_0"
                    CTV="q8_0"
                fi
                save_config
                ;;
            b|B|"")
                break
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Main Interactive Loop
# ------------------------------------------------------------------------------
while true; do
    print_header

    if is_running; then
        echo "  Actions:"
        echo "    1) Stop Server"
        echo "    2) Restart Server"
        echo "    3) Open Web UI in Browser"
        echo "    4) View Live Logs"
        echo "    5) Check Health / API Props"
        echo "    q) Quit"
        echo ""
        read -rp "  Choice: " opt
        case "$opt" in
            1)
                echo ""
                stop_server
                read -rp "  Press Enter to continue..."
                ;;
            2)
                echo ""
                stop_server
                start_server "$LAST_MODEL" "$CTX_SIZE" "$GPU_LAYERS" "$PORT" "$HOST"
                read -rp "  Press Enter to continue..."
                ;;
            3)
                xdg-open "http://${HOST}:${PORT}" >/dev/null 2>&1 || true
                ;;
            4)
                clear
                echo -e "  ${CLR_CYAN}Streaming logs from ${LOG_FILE} (Ctrl+C to return)...${CLR_RESET}\n"
                tail -n 60 -f "$LOG_FILE" || true
                ;;
            5)
                echo ""
                echo "  --- /health ---"
                curl -s "http://${HOST}:${PORT}/health" || echo "Failed to reach endpoint"
                echo ""
                echo "  --- /props ---"
                curl -s "http://${HOST}:${PORT}/props" | jq . 2>/dev/null || curl -s "http://${HOST}:${PORT}/props" || true
                echo ""
                read -rp "  Press Enter to continue..."
                ;;
            q|Q)
                echo "Exiting."
                exit 0
                ;;
            *)
                ;;
        esac
    else
        echo "  Actions:"
        echo "    1) Start Server (Quick Start)"
        echo "    2) Select Model & Start"
        echo "    3) Configure Parameters (Context, Port, GPU)"
        echo "    4) View Last Logs"
        echo "    q) Quit"
        echo ""
        read -rp "  Choice: " opt
        case "$opt" in
            1)
                model_to_run="$LAST_MODEL"
                if [[ -z "$model_to_run" || ! -f "$model_to_run" ]]; then
                    mapfile -t found_m < <(find_models "$MODELS_DIR")
                    if (( ${#found_m[@]} > 0 )); then
                        model_to_run="${found_m[0]}"
                    fi
                fi

                if [[ -n "$model_to_run" && -f "$model_to_run" ]]; then
                    echo ""
                    start_server "$model_to_run" "$CTX_SIZE" "$GPU_LAYERS" "$PORT" "$HOST"
                else
                    echo ""
                    echo -e "  ${CLR_RED}No model found to start.${CLR_RESET}"
                    echo "  Please choose option 2 to scan and select a model."
                fi
                read -rp "  Press Enter to continue..."
                ;;
            2)
                echo ""
                CHOSEN_MODEL=""
                if select_model_menu; then
                    echo ""
                    start_server "$CHOSEN_MODEL" "$CTX_SIZE" "$GPU_LAYERS" "$PORT" "$HOST"
                    read -rp "  Press Enter to continue..."
                fi
                ;;
            3)
                settings_menu
                ;;
            4)
                clear
                echo -e "  ${CLR_CYAN}Last logs from ${LOG_FILE} (Ctrl+C to return)...${CLR_RESET}\n"
                if [[ -f "$LOG_FILE" ]]; then
                    tail -n 60 "$LOG_FILE"
                else
                    echo "  No log file found."
                fi
                echo ""
                read -rp "  Press Enter to continue..."
                ;;
            q|Q)
                echo "Exiting."
                exit 0
                ;;
            *)
                ;;
        esac
    fi
done
