#!/usr/bin/env bash
# Hardware monitor and display scaling detection for HyprVibe
# Generates hardware-adaptive monitor configurations at install time.

detect_monitor_info() {
    local mon_name=""
    local width=1920
    local height=1080
    local refresh=60
    local scale=1.0

    # 1. Try hyprctl if active
    if command -v hyprctl >/dev/null 2>&1 && pgrep -x Hyprland >/dev/null 2>&1; then
        local mon_json
        mon_json="$(hyprctl monitors -j 2>/dev/null || true)"
        if [[ -n "$mon_json" && "$mon_json" != "[]" ]]; then
            mon_name="$(echo "$mon_json" | jq -r '.[0].name // empty' 2>/dev/null || true)"
            width="$(echo "$mon_json" | jq -r '.[0].width // 1920' 2>/dev/null || true)"
            height="$(echo "$mon_json" | jq -r '.[0].height // 1080' 2>/dev/null || true)"
            local max_avail_hz
            max_avail_hz="$(echo "$mon_json" | jq -r '.[0].availableModes[]?' 2>/dev/null | grep -oE '@[0-9]+' | tr -d '@' | sort -nr | head -n 1 || true)"
            if [[ -n "$max_avail_hz" && "$max_avail_hz" -gt 0 ]]; then
                refresh="$max_avail_hz"
            else
                refresh="$(echo "$mon_json" | jq -r '.[0].refreshRate // 60' 2>/dev/null | cut -d. -f1 || true)"
            fi
            scale="$(echo "$mon_json" | jq -r '.[0].scale // 1.0' 2>/dev/null || true)"

            if [[ -n "$mon_name" ]]; then
                printf "%s %s %s %s %s\n" "$mon_name" "$width" "$height" "$refresh" "$scale"
                return 0
            fi
        fi
    fi

    # 2. Sysfs DRM detection fallback
    for p in /sys/class/drm/card*-*/status; do
        [[ -f "$p" ]] || continue
        if grep -qx "connected" "$p" 2>/dev/null; then
            local dir
            dir="$(dirname "$p")"
            local base
            base="$(basename "$dir")"
            mon_name="${base#*-}"

            if [[ -f "${dir}/modes" ]]; then
                local top_mode
                top_mode="$(head -n 1 "${dir}/modes" 2>/dev/null || true)"
                if [[ "$top_mode" =~ ^([0-9]+)x([0-9]+) ]]; then
                    width="${BASH_REMATCH[1]}"
                    height="${BASH_REMATCH[2]}"
                fi
            fi

            # Detect max refresh rate from EDID if possible
            if command -v edid-decode >/dev/null 2>&1 && [[ -f "${dir}/edid" && -s "${dir}/edid" ]]; then
                local edid_max_hz
                edid_max_hz="$(edid-decode "${dir}/edid" 2>/dev/null | grep -iE 'Max(imum)? Refresh Rate:' | grep -oE '[0-9]+' | sort -nr | head -n 1 || true)"
                if [[ -n "$edid_max_hz" && "$edid_max_hz" -gt 0 ]]; then
                    refresh="$edid_max_hz"
                fi
            fi

            # Estimate DPI and scale
            local dpi=96
            if [[ -f "${dir}/edid" && -s "${dir}/edid" ]]; then
                local edid_data
                edid_data="$(od -An -N23 -j21 -tu1 "${dir}/edid" 2>/dev/null || true)"
                local w_cm h_cm
                read -r w_cm h_cm <<< "$edid_data"
                if [[ -n "$w_cm" && "$w_cm" -gt 0 ]]; then
                    dpi=$(awk -v w="$width" -v cm="$w_cm" 'BEGIN { printf "%d", w / (cm / 2.54) }')
                fi
            fi

            # Calculate adaptive scaling based on DPI and screen type
            if (( dpi >= 210 )); then
                scale=1.8
            elif (( dpi >= 170 )); then
                scale=1.5
            elif (( dpi >= 135 )); then
                scale=1.25
            elif [[ "$mon_name" =~ ^eDP ]] && (( height >= 1600 )); then
                scale=1.8
            elif [[ "$mon_name" =~ ^eDP ]] && (( height >= 1400 )); then
                scale=1.5
            else
                scale=1.0
            fi

            break
        fi
    done

    [[ -z "$mon_name" ]] && mon_name="eDP-1"
    printf "%s %s %s %s %s\n" "$mon_name" "$width" "$height" "$refresh" "$scale"
}

get_active_monitor_scale() {
    local repo_root="${1:-$HOME/HyprVibe}"
    local user_monitors="${repo_root}/dotfiles/hypr/.config/hypr/config/monitors.lua"
    if [[ ! -f "$user_monitors" && -f "${HOME}/.config/hypr/config/monitors.lua" ]]; then
        user_monitors="${HOME}/.config/hypr/config/monitors.lua"
    fi

    # Read scale from existing monitors.lua if available
    if [[ -f "$user_monitors" ]]; then
        local found_scale
        found_scale="$(grep -oE 'scale\s*=\s*[0-9]+(\.[0-9]+)?' "$user_monitors" | head -n 1 | awk -F= '{print $2}' | tr -d ' ' || true)"
        if [[ -n "$found_scale" ]]; then
            printf "%s\n" "$found_scale"
            return 0
        fi
    fi

    # Fallback to hardware detection
    local mon_info
    mon_info="$(detect_monitor_info)"
    read -r _ _ _ _ scale <<< "$mon_info"
    printf "%s\n" "${scale:-1.0}"
}

ensure_monitors_config() {
    local repo_root="${1:-$HOME/HyprVibe}"
    local target_file="${repo_root}/dotfiles/hypr/.config/hypr/config/monitors.lua"
    local template_file="${repo_root}/templates/hypr/monitors.lua.template"

    mkdir -p "$(dirname "$target_file")"

    local mon_name width height refresh scale
    read -r mon_name width height refresh scale <<< "$(detect_monitor_info)"

    local primary_rule=""
    if [[ -n "$mon_name" ]]; then
        primary_rule="hl.monitor({ output = \"${mon_name}\", mode = \"${width}x${height}@${refresh}\", position = \"auto\", scale = ${scale} })"
    fi

    if [[ -f "$template_file" ]]; then
        sed -e "s|{{SCALE}}|${scale}|g" \
            -e "s|{{PRIMARY_RULE}}|${primary_rule}|g" \
            "$template_file" > "$target_file"
    else
        cat > "$target_file" <<EOF
-- Auto-generated monitor configuration for Hyprland.
-- Generated dynamically at install time based on connected hardware.

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = ${scale} })
${primary_rule}
EOF
    fi

    # Also keep SDDM compositor config in sync
    sync_sddm_compositor_config "$repo_root"

    return 0
}

sync_sddm_compositor_config() {
    local repo_root="${1:-$HOME/HyprVibe}"
    local mon_name width height refresh scale
    read -r mon_name width height refresh scale <<< "$(detect_monitor_info)"

    local active_scale
    active_scale="$(get_active_monitor_scale "$repo_root")"
    [[ -n "$active_scale" ]] && scale="$active_scale"

    # Clamp SDDM refresh rate: if supported refresh >= 120, lock to 120Hz; else use native (fallback 60)
    local sddm_refresh=60
    if [[ -n "$refresh" && "$refresh" =~ ^[0-9]+$ ]]; then
        if (( refresh >= 120 )); then
            sddm_refresh=120
        else
            sddm_refresh="$refresh"
        fi
    fi

    local primary_rule=""
    if [[ -n "$mon_name" && -n "$width" && -n "$height" ]]; then
        primary_rule="hl.monitor({ output = \"${mon_name}\", mode = \"${width}x${height}@${sddm_refresh}\", position = \"auto\", scale = ${scale} })"
    fi

    local sddm_hyprland_repo="${repo_root}/dotfiles/sddm/hyprland.lua"
    local sddm_hyprland_sys="/usr/share/sddm/hyprland.lua"

    local config_content="-- Minimal Hyprland configuration for HyprVibe SDDM Wayland greeter.
-- Generated dynamically at install time based on hardware display scale and refresh rate.
hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    force_default_wallpaper = 0,
    vrr = 1,
  },
  animations = {
    enabled = true,
  },
})

-- Night light startup hook for SDDM greeter
hl.on(\"hyprland.start\", function()
  hl.exec_cmd(\"hyprsunset -t 3700 &\")
end)

-- Dynamic hardware monitor scaling & refresh rate
hl.monitor({ output = \"\", mode = \"preferred\", position = \"auto\", scale = ${scale} })
${primary_rule}
"

    # Write to repo
    printf "%s\n" "$config_content" > "$sddm_hyprland_repo" 2>/dev/null || true

    # Write to system if writable or non-interactive sudo available
    if [[ -d "/usr/share/sddm" ]]; then
        if [[ -w "/usr/share/sddm" || -w "$sddm_hyprland_sys" ]]; then
            printf "%s\n" "$config_content" > "$sddm_hyprland_sys" 2>/dev/null || true
        elif sudo -n true 2>/dev/null; then
            printf "%s\n" "$config_content" | sudo -n tee "$sddm_hyprland_sys" >/dev/null 2>&1 || true
        fi
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ensure_monitors_config "${1:-$HOME/HyprVibe}"
fi

