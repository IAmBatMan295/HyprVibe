# HyprVibe

My custom Hyprland setup for CachyOS and Arch Linux.

## Install Option 1: Direct curl

```bash
curl -fsSL https://raw.githubusercontent.com/IAmBatMan295/HyprVibe/main/bin/install.sh | bash
```

## Install Option 2: Clone and manual install

```bash
git clone https://github.com/IAmBatMan295/HyprVibe.git ~/HyprVibe
cd ~/HyprVibe
bash bin/install.sh
```

## Optional package profile override

The installer auto-detects your distro and chooses package lists automatically.
You can force a profile if needed:

```bash
HYPRVIBE_PACKAGE_PROFILE=cachy bash bin/install-packes.sh
HYPRVIBE_PACKAGE_PROFILE=arch bash bin/install-packes.sh
```

