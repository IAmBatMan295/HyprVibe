#!/usr/bin/env bash

# HyprVibe Theme Engine Library
# Handles colors.toml parsing, color resolution, and template rendering

declare -gA THEME_COLORS=()

hex_to_rgb() {
    local hex="${1#\#}"
    if [[ ${#hex} -eq 6 ]]; then
        printf "%d,%d,%d" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
    else
        printf "%s" "$1"
    fi
}

load_colors_file() {
    local colors_file="$1"
    THEME_COLORS=()

    if [[ ! -f "$colors_file" ]]; then
        echo "Error: colors file not found: $colors_file" >&2
        return 1
    fi

    local key value
    while IFS='=' read -r key value; do
        # Strip spaces and quotes from key
        key="${key//[\"\' ]/}"
        [[ -n "$key" && "$key" != \#* ]] || continue

        if [[ "$value" == *[\"\']* ]]; then
            value="${value#*[\"\']}"
            value="${value%%[\"\']*}"
        else
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
        fi

        THEME_COLORS["$key"]="$value"
    done < "$colors_file"

    # Semantic aliases & fallbacks
    [[ -n "${THEME_COLORS[background]:-}" ]] || THEME_COLORS[background]="${THEME_COLORS[bg]:-#000000}"
    [[ -n "${THEME_COLORS[foreground]:-}" ]] || THEME_COLORS[foreground]="${THEME_COLORS[fg]:-#ffffff}"
    [[ -n "${THEME_COLORS[lighter_background]:-}" ]] || THEME_COLORS[lighter_background]="${THEME_COLORS[selection]:-${THEME_COLORS[background]}}"
    [[ -n "${THEME_COLORS[dark_foreground]:-}" ]] || THEME_COLORS[dark_foreground]="${THEME_COLORS[muted]:-${THEME_COLORS[foreground]}}"
    [[ -n "${THEME_COLORS[accent]:-}" ]] || THEME_COLORS[accent]="${THEME_COLORS[blue]:-${THEME_COLORS[foreground]}}"
    [[ -n "${THEME_COLORS[selection]:-}" ]] || THEME_COLORS[selection]="${THEME_COLORS[lighter_background]}"
    [[ -n "${THEME_COLORS[muted]:-}" ]] || THEME_COLORS[muted]="${THEME_COLORS[dark_foreground]}"
    [[ -n "${THEME_COLORS[black]:-}" ]] || THEME_COLORS[black]="#000000"
    [[ -n "${THEME_COLORS[white]:-}" ]] || THEME_COLORS[white]="#ffffff"

    # ANSI mappings
    [[ -n "${THEME_COLORS[color0]:-}" ]] || THEME_COLORS[color0]="${THEME_COLORS[black]}"
    [[ -n "${THEME_COLORS[color1]:-}" ]] || THEME_COLORS[color1]="${THEME_COLORS[red]:-#ff0000}"
    [[ -n "${THEME_COLORS[color2]:-}" ]] || THEME_COLORS[color2]="${THEME_COLORS[green]:-#00ff00}"
    [[ -n "${THEME_COLORS[color3]:-}" ]] || THEME_COLORS[color3]="${THEME_COLORS[yellow]:-#ffff00}"
    [[ -n "${THEME_COLORS[color4]:-}" ]] || THEME_COLORS[color4]="${THEME_COLORS[blue]:-#0000ff}"
    [[ -n "${THEME_COLORS[color5]:-}" ]] || THEME_COLORS[color5]="${THEME_COLORS[magenta]:-#ff00ff}"
    [[ -n "${THEME_COLORS[color6]:-}" ]] || THEME_COLORS[color6]="${THEME_COLORS[cyan]:-#00ffff}"
    [[ -n "${THEME_COLORS[color7]:-}" ]] || THEME_COLORS[color7]="${THEME_COLORS[white]}"

    [[ -n "${THEME_COLORS[color8]:-}" ]] || THEME_COLORS[color8]="${THEME_COLORS[dark_foreground]}"
    [[ -n "${THEME_COLORS[color9]:-}" ]] || THEME_COLORS[color9]="${THEME_COLORS[bright_red]:-${THEME_COLORS[color1]}}"
    [[ -n "${THEME_COLORS[color10]:-}" ]] || THEME_COLORS[color10]="${THEME_COLORS[bright_green]:-${THEME_COLORS[color2]}}"
    [[ -n "${THEME_COLORS[color11]:-}" ]] || THEME_COLORS[color11]="${THEME_COLORS[bright_yellow]:-${THEME_COLORS[color3]}}"
    [[ -n "${THEME_COLORS[color12]:-}" ]] || THEME_COLORS[color12]="${THEME_COLORS[bright_blue]:-${THEME_COLORS[color4]}}"
    [[ -n "${THEME_COLORS[color13]:-}" ]] || THEME_COLORS[color13]="${THEME_COLORS[bright_magenta]:-${THEME_COLORS[color5]}}"
    [[ -n "${THEME_COLORS[color14]:-}" ]] || THEME_COLORS[color14]="${THEME_COLORS[bright_cyan]:-${THEME_COLORS[color6]}}"
    [[ -n "${THEME_COLORS[color15]:-}" ]] || THEME_COLORS[color15]="${THEME_COLORS[white]}"

    # Generate _strip and _rgb versions for every color
    local k v
    for k in "${!THEME_COLORS[@]}"; do
        v="${THEME_COLORS[$k]}"
        THEME_COLORS["${k}_strip"]="${v#\#}"
        if [[ "$v" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
            THEME_COLORS["${k}_rgb"]="$(hex_to_rgb "$v")"
        fi
    done

    return 0
}

get_theme_color() {
    local key="$1"
    local fallback="${2:-}"
    if [[ -n "${THEME_COLORS[$key]:-}" ]]; then
        printf "%s\n" "${THEME_COLORS[$key]}"
    elif [[ -n "$fallback" ]]; then
        printf "%s\n" "$fallback"
    else
        return 1
    fi
}

render_template() {
    local template_file="$1"
    local output_file="$2"

    if [[ ! -f "$template_file" ]]; then
        echo "Error: Template not found: $template_file" >&2
        return 1
    fi

    local sed_script
    sed_script="$(mktemp)"
    trap 'rm -f "$sed_script"' RETURN

    local key value
    for key in "${!THEME_COLORS[@]}"; do
        value="${THEME_COLORS[$key]}"
        printf 's|{{ %s }}|%s|g\n' "$key" "$value" >> "$sed_script"
    done

    mkdir -p "$(dirname "$output_file")"
    sed -f "$sed_script" "$template_file" > "$output_file"
    rm -f "$sed_script"
    trap - RETURN
    return 0
}

render_all_templates() {
    local templates_dir="$1"
    local output_dir="$2"

    if [[ ! -d "$templates_dir" ]]; then
        echo "Error: Templates directory not found: $templates_dir" >&2
        return 1
    fi

    mkdir -p "$output_dir"

    local tpl filename out_name
    shopt -s nullglob
    for tpl in "$templates_dir"/*.tpl; do
        filename="$(basename "$tpl")"
        out_name="${filename%.tpl}"
        render_template "$tpl" "${output_dir}/${out_name}"
    done
    shopt -u nullglob

    return 0
}
