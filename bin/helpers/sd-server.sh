#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Title: Local Image Generator
# Description: Helper script to generate images and run stable-diffusion.cpp server
# ==============================================================================

HELPER_TITLE="Local Image Generator"
HELPER_ICON="󰋩"
HELPER_ORDER=23

# ------------------------------------------------------------------------------
# Floating Window Spawn Logic (45% screen width x 48% height, centered)
# ------------------------------------------------------------------------------
IS_INNER=false
for a in "$@"; do
    case "$a" in
        --inner|--headless|--status|--dry-run-cmd|--detect-type|--start|--stop|--restart|--generate)
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
        hyprctl eval "hl.window_rule({ match = { class = 'sd-server-helper' }, float = true, center = true, size = '${TARGET_W} ${TARGET_H}' })" >/dev/null 2>&1 || true
        hyprctl eval "hl.exec_cmd('foot -a sd-server-helper -T \"${HELPER_TITLE}\" -w ${TARGET_W}x${TARGET_H} bash \"${SCRIPT_FILE}\" --inner \"$@\"')" >/dev/null 2>&1 || true
        exit 0
    fi
fi

# ------------------------------------------------------------------------------
# State & Configuration Paths
# ------------------------------------------------------------------------------
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sd-server"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sd-server"
CONFIG_FILE="${CONFIG_DIR}/sd-server.conf"
PID_FILE="${STATE_DIR}/sd-server.pid"
LOG_FILE="${HOME}/sd-server.log"
CURRENT_INFO_FILE="${STATE_DIR}/sd-server.current"

mkdir -p "$STATE_DIR" "$CONFIG_DIR"

MODELS_DIR="${HOME}/models/flux"
OUTPUT_DIR="${HOME}/Pictures/Generated"
DIFFUSION_MODEL="${HOME}/models/flux/flux1-dev-Q3_K_S.gguf"
VAE="${HOME}/models/flux/ae.safetensors"
CLIP_L="${HOME}/models/flux/clip_l.safetensors"
T5XXL="${HOME}/models/flux/t5xxl_q3_k_s.gguf"
STEPS=26
GUIDANCE=3.5
CFG_SCALE=1.0
WIDTH=1024
HEIGHT=1024
SEED=-1
PORT=8090
HOST="127.0.0.1"
VAE_TILING="on"

# Load persisted configuration if available
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE" 2>/dev/null || true
fi

mkdir -p "$OUTPUT_DIR"

save_config() {
    local rel_models="${MODELS_DIR/#$HOME/\${HOME\}}"
    local rel_out="${OUTPUT_DIR/#$HOME/\${HOME\}}"
    local rel_diff="${DIFFUSION_MODEL/#$HOME/\${HOME\}}"
    local rel_vae="${VAE/#$HOME/\${HOME\}}"
    local rel_clipl="${CLIP_L/#$HOME/\${HOME\}}"
    local rel_t5="${T5XXL/#$HOME/\${HOME\}}"

    cat > "$CONFIG_FILE" <<EOF
# Configuration for Local Image Generator Helper
# Managed via HyprVibe dotfiles (GNU Stow)

MODELS_DIR="${rel_models}"
OUTPUT_DIR="${rel_out}"
DIFFUSION_MODEL="${rel_diff}"
VAE="${rel_vae}"
CLIP_L="${rel_clipl}"
T5XXL="${rel_t5}"
STEPS=${STEPS}
GUIDANCE=${GUIDANCE}
CFG_SCALE=${CFG_SCALE}
WIDTH=${WIDTH}
HEIGHT=${HEIGHT}
SEED=${SEED}
PORT=${PORT}
HOST="${HOST}"
VAE_TILING="${VAE_TILING}"
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

    local proc_pid
    proc_pid=$(pgrep -x sd-server 2>/dev/null | head -n 1 || true)
    if [[ -n "$proc_pid" ]]; then
        echo "$proc_pid"
        return 0
    fi
    return 1
}

is_running() {
    get_server_pid >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# Model Architecture Detection & Profiles
# ------------------------------------------------------------------------------
detect_model_type() {
    local target="$1"
    local lower
    lower=$(echo "$target" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower" =~ sdxl|xl|juggernaut|realvis|pony|animagine|albedobase ]]; then
        echo "sdxl"
    elif [[ "$lower" =~ 1\.5|v1-5|sd15|dreamshaper|deliberate|epicrealism ]]; then
        echo "sd15"
    elif [[ "$lower" =~ flux ]]; then
        echo "flux"
    elif [[ "$lower" =~ sd3|sd-3 ]]; then
        echo "sd3"
    else
        echo "sdxl"
    fi
}

apply_model_defaults() {
    local target="$1"
    local m_type
    m_type=$(detect_model_type "$target")
    case "$m_type" in
        sdxl)
            WIDTH=1024
            HEIGHT=1024
            STEPS=25
            CFG_SCALE=7.0
            GUIDANCE=0.0
            ;;
        sd15)
            WIDTH=512
            HEIGHT=512
            STEPS=20
            CFG_SCALE=7.0
            GUIDANCE=0.0
            ;;
        flux)
            WIDTH=1024
            HEIGHT=1024
            STEPS=26
            CFG_SCALE=1.0
            GUIDANCE=3.5
            ;;
    esac
}

find_models() {
    local search_dirs=("$MODELS_DIR" "${HOME}/models" "${HOME}/models/sd")
    local found=()
    for sdir in "${search_dirs[@]}"; do
        if [[ -d "$sdir" ]]; then
            while IFS= read -r -d '' f; do
                local bname
                bname=$(basename "$f")
                if [[ "$bname" =~ ^(Qwen|qwen|t5|clip|ae|vae) ]]; then
                    continue
                fi
                found+=("$f")
            done < <(find "$sdir" -maxdepth 2 -type f \( -name "*.safetensors" -o -name "*.gguf" -o -name "*.ckpt" \) -print0 2>/dev/null)
        fi
    done
    printf '%s\n' "${found[@]}" | sort -u
}

build_cmd_args() {
    local target_model="${1:-$DIFFUSION_MODEL}"
    local m_type
    m_type=$(detect_model_type "$target_model")

    local m_w="$WIDTH"
    local m_h="$HEIGHT"
    local m_steps="$STEPS"
    local m_cfg="$CFG_SCALE"
    local m_guide="$GUIDANCE"

    local cmd=""
    if [[ "$m_type" == "flux" ]]; then
        cmd="sd-cli --diffusion-model \"$target_model\" --vae \"$VAE\" --clip_l \"$CLIP_L\" --t5xxl \"$T5XXL\" -W $m_w -H $m_h --steps $m_steps --guidance $m_guide --cfg-scale $m_cfg -s $SEED --auto-fit on"
    elif [[ "$m_type" == "sdxl" ]]; then
        if [[ -n "${1:-}" && "$1" != "$DIFFUSION_MODEL" ]]; then
            m_w=1024
            m_h=1024
            m_steps=25
            m_cfg=7.0
        fi
        cmd="sd-cli -m \"$target_model\" -W $m_w -H $m_h --steps $m_steps --cfg-scale $m_cfg -s $SEED"
    elif [[ "$m_type" == "sd15" ]]; then
        if [[ -n "${1:-}" && "$1" != "$DIFFUSION_MODEL" ]]; then
            m_w=512
            m_h=512
            m_steps=20
            m_cfg=7.0
        fi
        cmd="sd-cli -m \"$target_model\" -W $m_w -H $m_h --steps $m_steps --cfg-scale $m_cfg -s $SEED"
    else
        cmd="sd-cli -m \"$target_model\" -W $m_w -H $m_h --steps $m_steps --cfg-scale $m_cfg -s $SEED"
    fi

    if [[ "$VAE_TILING" == "on" ]]; then
        cmd="$cmd --vae-tiling"
    fi
    echo "$cmd"
}

start_server() {
    if is_running; then
        echo "  Server already running (PID: $(get_server_pid)). Stop or restart first."
        return 1
    fi

    local target_model="${1:-$DIFFUSION_MODEL}"
    if [[ ! -f "$target_model" ]]; then
        echo "  Error: Model file does not exist: $target_model"
        return 1
    fi

    local m_type
    m_type=$(detect_model_type "$target_model")

    echo "  Starting sd-server..."
    echo "  Model:    $(basename "$target_model") (Profile: ${m_type^^})"
    echo "  Size:     ${WIDTH}x${HEIGHT} | Steps: ${STEPS} | CFG: ${CFG_SCALE}"
    echo "  Listen:   http://${HOST}:${PORT}"

    local extra_args=()
    if [[ "$VAE_TILING" == "on" ]]; then
        extra_args+=("--vae-tiling")
    fi

    local model_flags=()
    if [[ "$m_type" == "flux" ]]; then
        extra_args+=("--auto-fit" "on")
        model_flags=(
            --diffusion-model "$target_model"
            --vae "$VAE"
            --clip_l "$CLIP_L"
            --t5xxl "$T5XXL"
            --guidance "$GUIDANCE"
        )
    else
        model_flags=(-m "$target_model")
    fi

    setsid -f sd-server \
        --listen-ip "$HOST" \
        --listen-port "$PORT" \
        "${model_flags[@]}" \
        -W "$WIDTH" \
        -H "$HEIGHT" \
        --steps "$STEPS" \
        --cfg-scale "$CFG_SCALE" \
        -s "$SEED" \
        "${extra_args[@]}" >> "$LOG_FILE" 2>&1 < /dev/null

    local pid=""
    for _ in {1..20}; do
        pid=$(pgrep -x sd-server 2>/dev/null | head -n 1 || true)
        [[ -n "$pid" ]] && break
        sleep 0.1
    done

    if [[ -z "$pid" ]]; then
        echo "  ❌ Failed to launch sd-server process."
        tail -n 10 "$LOG_FILE"
        return 1
    fi

    echo "$pid" > "$PID_FILE"
    cat > "$CURRENT_INFO_FILE" <<EOF
MODEL="$target_model"
TYPE="$m_type"
WIDTH=$WIDTH
HEIGHT=$HEIGHT
STEPS=$STEPS
PORT=$PORT
HOST=$HOST
START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
EOF

    echo "  ✔ Server successfully started (PID: $pid)"
    command -v notify-send >/dev/null 2>&1 && \
        notify-send -a "${HELPER_TITLE}" "${HELPER_TITLE}" "Image server running at http://${HOST}:${PORT}" || true
    return 0
}

stop_server() {
    local pid
    pid=$(get_server_pid || true)
    if [[ -z "$pid" ]]; then
        echo "  Server is not running."
        rm -f "$PID_FILE" "$CURRENT_INFO_FILE"
        return 0
    fi

    echo "  Stopping sd-server (PID: $pid)..."
    kill "$pid" 2>/dev/null || true

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

generate_image() {
    local prompt="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local out_file="${OUTPUT_DIR}/flux_${timestamp}.png"

    echo ""
    echo "  Generating image with FLUX.1..."
    echo "  Prompt:  \"$prompt\""
    echo "  Output:  $out_file"
    local m_type
    m_type=$(detect_model_type "$DIFFUSION_MODEL")

    echo "  Generating image with ${m_type^^}..."
    echo "  Prompt:  \"$prompt\""
    echo "  Output:  $out_file"
    echo "  Size:    ${WIDTH}x${HEIGHT} | Steps: ${STEPS} | CFG: ${CFG_SCALE}"
    echo ""

    local extra_args=()
    if [[ "$VAE_TILING" == "on" ]]; then
        extra_args+=("--vae-tiling")
    fi

    local model_flags=()
    if [[ "$m_type" == "flux" ]]; then
        extra_args+=("--auto-fit" "on")
        model_flags=(
            --diffusion-model "$DIFFUSION_MODEL"
            --vae "$VAE"
            --clip_l "$CLIP_L"
            --t5xxl "$T5XXL"
            --guidance "$GUIDANCE"
        )
    else
        model_flags=(-m "$DIFFUSION_MODEL")
    fi

    sd-cli \
        "${model_flags[@]}" \
        -W "$WIDTH" \
        -H "$HEIGHT" \
        --steps "$STEPS" \
        --cfg-scale "$CFG_SCALE" \
        -s "$SEED" \
        -p "$prompt" \
        -o "$out_file" \
        "${extra_args[@]}"

    if [[ -f "$out_file" ]]; then
        echo ""
        echo "  ✔ Image saved to: $out_file"
        command -v notify-send >/dev/null 2>&1 && \
            notify-send -a "${HELPER_TITLE}" -i "$out_file" "Image Generated" "Saved to $out_file" || true
        command -v xdg-open >/dev/null 2>&1 && xdg-open "$out_file" >/dev/null 2>&1 &
    else
        echo "  ❌ Generation failed."
    fi
}

# ------------------------------------------------------------------------------
# CLI Argument Handling
# ------------------------------------------------------------------------------
ACTION=""
PROMPT_ARG=""
TARGET_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --status)
            ACTION="status"
            shift
            ;;
        --detect-type)
            ACTION="detect-type"
            TARGET_ARG="${2:-}"
            shift 2
            ;;
        --dry-run-cmd)
            ACTION="dry-run-cmd"
            TARGET_ARG="${2:-}"
            if [[ -n "$TARGET_ARG" && "$TARGET_ARG" != --* ]]; then
                shift 2
            else
                TARGET_ARG=""
                shift 1
            fi
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
        --generate)
            ACTION="generate"
            PROMPT_ARG="${2:-}"
            shift 2
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
            else
                echo "stopped"
            fi
            exit 0
            ;;
        detect-type)
            detect_model_type "$TARGET_ARG"
            exit 0
            ;;
        dry-run-cmd)
            build_cmd_args "$TARGET_ARG"
            exit 0
            ;;
        start)
            start_server
            exit $?
            ;;
        stop)
            stop_server
            exit 0
            ;;
        restart)
            stop_server
            start_server
            exit $?
            ;;
        generate)
            if [[ -z "$PROMPT_ARG" ]]; then
                echo "Error: --generate requires a prompt string" >&2
                exit 1
            fi
            generate_image "$PROMPT_ARG"
            exit $?
            ;;
    esac
fi

# ------------------------------------------------------------------------------
# UI Helpers & Menu Loop
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
        echo -e "  Server Status: ${CLR_GREEN}${CLR_BOLD}● RUNNING${CLR_RESET} (PID: ${pid})"
        echo -e "  Endpoint:      ${CLR_CYAN}http://${HOST}:${PORT}${CLR_RESET}"
    else
        echo -e "  Server Status: ${CLR_RED}○ STOPPED${CLR_RESET}"
    fi

    echo -e "  Model:         $(basename "$DIFFUSION_MODEL")"
    echo -e "  Resolution:    ${WIDTH}x${HEIGHT} | Steps: ${STEPS} | Guidance: ${GUIDANCE}"
    echo -e "  Output Folder: ${OUTPUT_DIR}"
    echo -e "  ${CLR_GRAY}──────────────────────────────────────────────────${CLR_RESET}"
    echo ""
}

settings_menu() {
    while true; do
        print_header
        echo "  Settings:"
        echo "    1) Resolution:       ${WIDTH}x${HEIGHT}"
        echo "    2) Sampling Steps:   ${STEPS}"
        echo "    3) Guidance Scale:   ${GUIDANCE}"
        echo "    4) VAE Tiling:       ${VAE_TILING} (reduces VRAM)"
        echo "    5) Output Directory: ${OUTPUT_DIR}"
        echo "    b) Back"
        echo ""
        read -rp "  Choice [1-5, b]: " s_opt
        case "$s_opt" in
            1)
                echo ""
                echo "    1) 1024x1024 (Standard FLUX)"
                echo "    2) 1280x768  (Landscape 16:9 approx)"
                echo "    3) 768x1280  (Portrait)"
                echo "    4) 768x768   (Faster)"
                read -rp "  Select [1-4]: " r_opt
                case "$r_opt" in
                    1) WIDTH=1024; HEIGHT=1024 ;;
                    2) WIDTH=1280; HEIGHT=768 ;;
                    3) WIDTH=768; HEIGHT=1280 ;;
                    4) WIDTH=768; HEIGHT=768 ;;
                esac
                save_config
                ;;
            2)
                read -rp "  Enter steps [default: 20]: " n_steps
                [[ "$n_steps" =~ ^[0-9]+$ ]] && STEPS="$n_steps"
                save_config
                ;;
            3)
                read -rp "  Enter guidance scale [default: 3.5]: " n_guide
                [[ -n "$n_guide" ]] && GUIDANCE="$n_guide"
                save_config
                ;;
            4)
                if [[ "$VAE_TILING" == "on" ]]; then
                    VAE_TILING="off"
                else
                    VAE_TILING="on"
                fi
                save_config
                ;;
            5)
                read -rp "  Enter output path: " n_out
                [[ -n "$n_out" ]] && OUTPUT_DIR="$n_out"
                mkdir -p "$OUTPUT_DIR"
                save_config
                ;;
            b|B|"")
                break
                ;;
        esac
    done
}

while true; do
    print_header
    echo "  Actions:"
    echo "    1) Generate Image (Enter Prompt)"
    if is_running; then
        echo "    2) Stop API / Web Server"
        echo "    3) Restart Server"
    else
        echo "    2) Start API / Web Server (port ${PORT})"
    fi
    echo "    3) Open Generated Images Folder"
    echo "    4) Configure Settings (Resolution, Steps, Guidance)"
    echo "    5) View Last Server Logs"
    echo "    q) Quit"
    echo ""
    read -rp "  Choice: " opt
    case "$opt" in
        1)
            echo ""
            read -rp "  Enter prompt: " user_prompt
            if [[ -n "$user_prompt" ]]; then
                generate_image "$user_prompt"
            fi
            read -rp "  Press Enter to continue..."
            ;;
        2)
            echo ""
            if is_running; then
                stop_server
            else
                start_server
            fi
            read -rp "  Press Enter to continue..."
            ;;
        3)
            if is_running; then
                stop_server
                start_server
                read -rp "  Press Enter to continue..."
            else
                command -v xdg-open >/dev/null 2>&1 && xdg-open "$OUTPUT_DIR" >/dev/null 2>&1 &
            fi
            ;;
        4)
            settings_menu
            ;;
        5)
            clear
            echo -e "  ${CLR_CYAN}Streaming logs from ${LOG_FILE} (Ctrl+C to return)...${CLR_RESET}\n"
            tail -n 60 -f "$LOG_FILE" || true
            ;;
        q|Q)
            echo "Exiting."
            exit 0
            ;;
        *)
            ;;
    esac
done
