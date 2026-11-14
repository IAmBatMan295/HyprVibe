# HyprVibe Health & Design Language Audit — Partial Plan

**Task Category**: 10. Investigate Unknown (Findings and recommendations without codebase modification)
**Target**: Comprehensive codebase health check across design language, bugs, dead code, edge cases, and architectural integrity.

---

## 1. Candidate Subtasks & Exploration Scope

### Subsystem 1: Design Language & Theming Synchronization
- **Files to examine**:
  - `dotfiles/hypr/.config/hypr/theme.lua`, `dotfiles/hypr/.config/hypr/hyprland.conf`
  - `dotfiles/quickshell/` (Bar, SystemMenu, Panel colors, fonts)
  - `dotfiles/nvim/.config/nvim/lua/config/` (Theme sync, plugin sync)
  - `dotfiles/foot/.config/foot/foot.ini`
  - `dotfiles/rofi/.config/rofi/`
  - `dotfiles/sddm/`
  - `dotfiles/dunst/.config/dunst/dunstrc`
- **Coupling & Dependencies**:
  - `bin/hyprvibe-theme` / theme switcher scripts
  - Dynamic palette broadcast across GUI components.
- **Blast Radius / Risks**:
  - Theme switching breaks contrast or causes unreadable text in specific components.
  - Hardcoded color codes bypassing dynamic theme engine.

### Subsystem 2: Helper Scripts, Process Lifecycle & Edge Cases
- **Files to examine**:
  - `bin/helpers/sd-server.sh`, `bin/helpers/llama-server.sh`
  - `dotfiles/hypr/.config/hypr/scripts/` (`wallpaper-changer.sh`, `screen-record.sh`, `helpers-menu.sh`, `screenshot.sh`, `power-profiles.sh`, `toggle-refresh.sh`)
- **Coupling & Dependencies**:
  - Systemd user session, Foot terminal floating windows, Hyprland socket / `hyprctl`.
- **Blast Radius / Risks**:
  - Zombie processes, uncaught script exits (`set -e` triggers without clean exit), race conditions on port bindings, missing directories.

### Subsystem 3: Dead Code, Redundant Artifacts & Unused Files
- **Files to examine**:
  - Git status untracked files
  - Unused dotfiles packages in `dotfiles/`
  - Deprecated script references in `bin/` and `dotfiles/hypr/.config/hypr/`
- **Blast Radius / Risks**:
  - Cluttered repository, orphaned configs installed via Stow that no longer function.

### Subsystem 4: Packaging & Environment Dependencies
- **Files to examine**:
  - `packages/pacman.txt`, `packages/aur.txt`
  - Tool invocations across all scripts (`hyprctl`, `jq`, `awk`, `notify-send`, `sox`, `wf-recorder`, `slurp`, `grim`, `swappy`, `ffmpeg`, etc.)
- **Blast Radius / Risks**:
  - Clean install on fresh machine fails because a runtime dependency was omitted from package manifests.

---

## 2. Research Strategy
1. Inspect git status, untracked files, and stow packages.
2. Scan all shell scripts with shellcheck patterns and inspect error handling / edge cases.
3. Audit QML and UI styles for hardcoded values vs theme variables.
4. Cross-check binary invocations against `packages/pacman.txt` and `packages/aur.txt`.
5. Synthesize findings into final plan and detailed report.
