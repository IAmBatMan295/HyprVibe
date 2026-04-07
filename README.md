# HyprVibe

My custom Hyprland setup for CachyOS and Arch Linux.

```bash
curl -fsSL https://raw.githubusercontent.com/IAmBatMan295/HyprVibe/main/bin/install.sh | { if [ "$(id -u)" -eq 0 ]; then u="${SUDO_USER:-$(logname 2>/dev/null || true)}"; [ -n "$u" ] && exec sudo -H -u "$u" bash || { echo "Run from a normal user session (or set SUDO_USER)." >&2; exit 1; }; else exec bash; fi; }
```

