# Quickshell Bar Manual Configuration Guide

Quick single-variable configuration reference for the HyprVibe Quickshell bar.

---

## 1. Behavior & Timers

### Hover Reveal Delay (Top Edge Mist-Hover Filter)
- **File**: `dotfiles/quickshell/.config/quickshell/plugins/bar/Bar.qml`
- **Object**: `Timer { id: revealTimer }`
- **Property**: `interval`
- **Values**:
  - `500` *(default)*: 500ms delay. Ignores fast mouse movements across the top.
  - `200`: 200ms delay. Quicker response.
  - `0`: Instant reveal on edge contact.
  - `1000`: 1s deliberate hover required.

### Autohide Hold Duration (Time Active Before Hiding)
- **File**: `dotfiles/quickshell/.config/quickshell/plugins/bar/Bar.qml`
- **Object**: `Timer { id: autohideTimer }`
- **Property**: `interval`
- **Values**:
  - `5000` *(current)*: 5 seconds active before auto-closing.
  - `10000`: 10 seconds active.
  - `3000`: 3 seconds quick dismiss.
  - `30000`: 30 seconds extended visibility.

### Autohide Mode Toggle
- **File**: `dotfiles/quickshell/.config/quickshell/shell.json`
- **Object**: `"bar"`
- **Property**: `"autohide"`
- **Values**:
  - `false` *(current)*: Bar stays visible until manually toggled with `SUPER+W`.
  - `true`: Bar autohides when mouse leaves; reveals on top hover or `SUPER+W`.

### Top Edge Trigger Thickness (Hover Detection Zone)
- **File**: `dotfiles/quickshell/.config/quickshell/plugins/bar/Bar.qml`
- **Object**: `PanelWindow { id: edgeTriggerWindow }`
- **Property**: `implicitHeight`
- **Values**:
  - `4` *(default)*: 4px transparent strip at top of screen.
  - `2`: 2px ultra-thin strip (less accidental activation).
  - `8`: 8px wider strip (easier to hit with cursor).

---

## 2. Layout & Compositor Modes

### Overlay vs Push Mode (Window Resizing / TUI Flicker)
- **File**: `dotfiles/quickshell/.config/quickshell/plugins/bar/Bar.qml`
- **Object**: `component BarPanel: PanelWindow`
- **Property**: `exclusionMode`
- **Values**:
  - `effectivelyHidden ? ExclusionMode.Ignore : ExclusionMode.Auto` *(current)*: Push mode. Bar allocates exclusive screen space and pushes windows down by 30px when revealed.
  - `ExclusionMode.Ignore`: Overlay mode. Bar floats above windows without resizing them.

### Bar Screen Edge Position
- **File**: `dotfiles/quickshell/.config/quickshell/shell.json`
- **Object**: `"bar"`
- **Property**: `"position"`
- **Values**:
  - `"top"` *(default)*: Bar anchors to top monitor edge.
  - `"bottom"`: Bar anchors to bottom monitor edge.

---

## 3. Visuals & Animations

### Bar Background Opacity (Transparency Level)
- **File**: `dotfiles/quickshell/.config/quickshell/plugins/bar/Bar.qml`
- **Object**: `component BarPanel: PanelWindow`
- **Property**: `color`
- **Values**:
  - `Util.alpha(root.background, 0.8)` *(default)*: 80% opacity with compositor blur.
  - `Util.alpha(root.background, 1.0)`: 100% solid, fully opaque.
  - `Util.alpha(root.background, 0.5)`: 50% translucent glass.
  - `Util.alpha(root.background, 0.0)`: 100% transparent (only widgets visible).

### Slide Animation Speed
- **File**: `dotfiles/quickshell/.config/quickshell/plugins/bar/Bar.qml`
- **Object**: `component BarPanel: PanelWindow` -> `margins` -> `NumberAnimation`
- **Property**: `duration`
- **Values**:
  - `220` *(default)*: 220ms smooth slide transition.
  - `100`: Snappy 100ms pop.
  - `400`: Slow 400ms glide.

### Hyprland Layer Blur
- **File**: `dotfiles/hypr/.config/hypr/config/rules.lua`
- **Object**: `hl.layer_rule({ match = { namespace = "hyprvibe-bar" }, ... })`
- **Property**: `blur`
- **Values**:
  - `true` *(default)*: Compositor blurs windows and wallpapers behind bar.
  - `false`: Disables blur beneath bar.

---

## 4. Widgets & Tooltips

### Clock Date & Time Format
- **File**: `dotfiles/quickshell/.config/quickshell/shell.json`
- **Object**: `"id": "hyprvibe.clock"`
- **Property**: `"format"`
- **Values**:
  - `"dddd  h:mm AP  d MMMM"` *(default)*: e.g., `Friday  4:10 PM  16 October`
  - `"h:mm AP"`: Minimalist time only, e.g., `4:10 PM`
  - `"HH:mm"`: 24-hour time, e.g., `16:10`
  - `"ddd, MMM d  h:mm AP"`: Compact date and time, e.g., `Fri, Oct 16  4:10 PM`

### Backlight Scroll Step Size
- **File**: `dotfiles/quickshell/.config/quickshell/plugins/bar/widgets/Backlight.qml`
- **Object**: `function adjustBrightness(delta)`
- **Variable**: `var step`
- **Values**:
  - `1` *(default)*: 1% brightness change per mouse scroll tick.
  - `5`: 5% standard step.
  - `10`: 10% coarse step.

---

## 5. Keyboard Shortcut

### Hyprland Bar Overlay Toggle Keybind
- **File**: `dotfiles/hypr/.config/hypr/config/binds.lua`
- **Object**: `hl.bind`
- **Property**: First argument (key chord string)
- **Values**:
  - `mainMod .. " + W"` *(default)*: `SUPER + W` toggles bar show/hide.
  - `mainMod .. " + B"`: `SUPER + B`.
  - `mainMod .. " + Escape"`: `SUPER + Esc`.
