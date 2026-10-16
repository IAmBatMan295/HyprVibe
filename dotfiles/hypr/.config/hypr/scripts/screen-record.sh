#!/bin/bash

# State-based screen recorder using wf-recorder
# Toggle script: First run opens menu to start, second run stops recording

RECORDINGS_DIR="$HOME/Pictures/Recordings"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp/hyprvibe-$UID}"
mkdir -p "$STATE_DIR" "$RECORDINGS_DIR"
PIDFILE="$STATE_DIR/wf-recorder.pid"
LOGFILE="$STATE_DIR/wf-recorder.log"

# Check if recording is active (running state)
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    # RUNNING STATE -> CLOSED STATE: Stop recording
    kill -SIGINT "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
    notify-send "Recording Stopped" "Saved to $RECORDINGS_DIR" -t 3000
    exit 0
fi

# CLOSED STATE -> RUNNING STATE: Show menu and start recording
if ! command -v wf-recorder >/dev/null 2>&1; then
    notify-send -u critical "Screen Recorder" "wf-recorder is not installed" 2>/dev/null || true
    exit 1
fi

# Recording profiles (optimized for Vega 8 + HDD)
# Video: h264_vaapi hardware encoding, 1080p
# Audio: 256kbps AAC, Lossless FLAC, or No Audio
profiles=(
    "30fps • 256kbps"
    "30fps • Lossless"
    "30fps • No Audio"
    "60fps • 256kbps"
    "60fps • Lossless"
    "60fps • No Audio"
)

# Show rofi menu (auto-size, 6 lines)
selected=$(printf '%s\n' "${profiles[@]}" | rofi -dmenu -i -p "Screen Record" -theme-str 'listview {lines: 6;} entry {width: 200px;}')

# Exit if nothing selected (Escape pressed)
[ -z "$selected" ] && exit 0

# Parse selection
case "$selected" in
    "30fps • 256kbps")
        FPS=30
        AUDIO_CODEC="aac"
        AUDIO_BITRATE="256k"
        NO_AUDIO=false
        EXT="mp4"
        LABEL="30fps-1080p-256kbps"
        ;;
    "30fps • Lossless")
        FPS=30
        AUDIO_CODEC="flac"
        AUDIO_BITRATE=""
        NO_AUDIO=false
        EXT="mkv"
        LABEL="30fps-1080p-lossless"
        ;;
    "30fps • No Audio")
        FPS=30
        NO_AUDIO=true
        EXT="mp4"
        LABEL="30fps-1080p-no-audio"
        ;;
    "60fps • 256kbps")
        FPS=60
        AUDIO_CODEC="aac"
        AUDIO_BITRATE="256k"
        NO_AUDIO=false
        EXT="mp4"
        LABEL="60fps-1080p-256kbps"
        ;;
    "60fps • Lossless")
        FPS=60
        AUDIO_CODEC="flac"
        AUDIO_BITRATE=""
        NO_AUDIO=false
        EXT="mkv"
        LABEL="60fps-1080p-lossless"
        ;;
    "60fps • No Audio")
        FPS=60
        NO_AUDIO=true
        EXT="mp4"
        LABEL="60fps-1080p-no-audio"
        ;;
    *)
        exit 1
        ;;
esac

# Generate filename with timestamp
FILENAME="recording-$(date +%Y-%m-%d_%H-%M-%S).$EXT"
OUTPUT="$RECORDINGS_DIR/$FILENAME"

detect_encoder() {
    local render_node
    render_node="${RENDER_DEV:-$(find /dev/dri -name "renderD*" 2>/dev/null | sort | head -n 1 || true)}"

    # Check VAAPI (AMD / Intel)
    if [[ -n "$render_node" && -e "$render_node" ]]; then
        if command -v vainfo >/dev/null 2>&1 && vainfo >/dev/null 2>&1; then
            echo "h264_vaapi nv12"
            return 0
        elif ffmpeg -init_hw_device vaapi=va:"$render_node" -f lavfi -i nullsrc=s=256x256:d=0.01 -vf 'format=nv12,hwupload' -c:v h264_vaapi -f null - >/dev/null 2>&1; then
            echo "h264_vaapi nv12"
            return 0
        fi
    fi

    # Check NVENC (Nvidia)
    if command -v nvidia-smi >/dev/null 2>&1 && ffmpeg -encoders 2>/dev/null | grep -q "h264_nvenc"; then
        echo "h264_nvenc yuv420p"
        return 0
    fi

    # Software fallback
    echo "libx264 yuv420p"
    return 1
}

if [ "$FPS" -eq 30 ]; then
    BITRATE="8M"
    GOP="60"
else
    BITRATE="15M"
    GOP="120"
fi

# Build audio parameters and command
AUDIO_PARAMS=()
if [ "$NO_AUDIO" != true ]; then
    DEFAULT_SINK=$(pactl get-default-sink 2>/dev/null || true)
    AUDIO_SOURCE="${DEFAULT_SINK}.monitor"
    
    AUDIO_PARAMS=("-a=$AUDIO_SOURCE" "-R" "48000" "-C" "$AUDIO_CODEC")
    if [ -n "$AUDIO_BITRATE" ]; then
        AUDIO_PARAMS+=("-P" "b=$AUDIO_BITRATE")
    fi
fi

# Detect encoder and configure params
read -r VIDEO_CODEC PIX_FMT < <(detect_encoder || true)

if [[ "$VIDEO_CODEC" == "libx264" ]]; then
    notify-send "Screen Record" "Hardware encoder unavailable. Using software encoding (libx264)" -t 3000
fi

RENDER_DEV="${RENDER_DEV:-$(find /dev/dri -name "renderD*" 2>/dev/null | sort | head -n 1 || true)}"
CODEC_PARAMS=("-p" "pix_fmt=$PIX_FMT" "-p" "b=$BITRATE" "-p" "g=$GOP")
if [[ "$VIDEO_CODEC" == "h264_vaapi" && -n "$RENDER_DEV" && -e "$RENDER_DEV" ]]; then
    CODEC_PARAMS+=("-d" "$RENDER_DEV")
fi

# Start recording in background
nohup wf-recorder \
    --codec="$VIDEO_CODEC" \
    -r "$FPS" \
    "${AUDIO_PARAMS[@]}" \
    "${CODEC_PARAMS[@]}" \
    -f "$OUTPUT" > "$LOGFILE" 2>&1 &

# Save PID for state management
echo $! > "$PIDFILE"

# Notify user
notify-send "Recording Started" "$LABEL" -t 2000

exit 0
