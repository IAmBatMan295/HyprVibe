# HyprVibe Health & Design Language Audit — Final Plan

**Task Category**: 10. Investigate Unknown
**Mode**: Read-Only Research & Reporting (Zero Code Modifications)

---

## Ordered Atomic Investigation Subtasks

### Subtask 1: Theming & Visual Design Language Audit
- **Files**:
  - `dotfiles/quickshell/**/*.qml`
  - `dotfiles/hypr/.config/hypr/theme.lua`
  - `dotfiles/nvim/.config/nvim/lua/config/theme-sync.lua`
  - `dotfiles/foot/.config/foot/foot.ini`
  - `dotfiles/rofi/.config/rofi/config.rasi`
  - `dotfiles/dunst/.config/dunst/dunstrc`
- **Focus**: Check for hardcoded colors, mismatched corner radii, font divergence, and contrast issues.
- **Verification**: Script scan for hardcoded hex colors bypassing theme variables.

### Subtask 2: Helper Scripts & Runtime Edge Cases Audit
- **Files**:
  - `bin/helpers/sd-server.sh`, `bin/helpers/llama-server.sh`
  - `dotfiles/hypr/.config/hypr/scripts/*.sh`
- **Focus**: Trap handlers, port conflicts, PID race conditions, missing input sanitization, unhandled external tool failures.
- **Verification**: Static analysis and edge case tracing.

### Subtask 3: Dead Code, Redundancy & Dotfiles Stow Audit
- **Files**:
  - `bin/stow-dotfiles.sh`
  - `dotfiles/` package tree vs `stow-dotfiles.sh` packages list
  - Untracked files and unused helper scripts
- **Focus**: Orphaned packages, unused legacy scripts, obsolete dotfiles directories.
- **Verification**: Tree comparison and reference search across codebase.

### Subtask 4: Packaging & Runtime Dependency Audit
- **Files**:
  - `packages/pacman.txt`, `packages/aur.txt`
  - Binaries invoked in `bin/` and `dotfiles/**/*.sh`
- **Focus**: Identify any commands called in scripts that are not listed in package manifests.
- **Verification**: Command extraction script compared against package lists.

### Subtask 5: Compile Health & Architecture Audit Report
- **Deliverable**: Comprehensive report with actionable insights, classified by severity (Critical, Warning, Optimization).
