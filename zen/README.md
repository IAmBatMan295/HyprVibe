Zen keepsake snapshot (manual restore)

This folder is intentionally NOT stow-managed.
It is a manual backup of your Zen settings and add-on/mod metadata.

Copy targets on a new machine:

1) Find your active Zen profile folder in:
   ~/.config/zen/profiles.ini or ~/.config/zen/installs.ini

2) Copy these files into that active profile folder:
   - prefs.js
   - extensions.json
   - extension-settings.json
   - extension-preferences.json
   - zen-themes.json
   - zen-keyboard-shortcuts.json
   - xulstore.json
   - zen-themes.css -> ~/.config/zen/<profile>/chrome/zen-themes.css

3) Copy mod files:
   - mods/<mod-id>/chrome.css -> ~/.config/zen/<profile>/chrome/zen-themes/<mod-id>/chrome.css
   - mods/<mod-id>/preferences.json -> ~/.config/zen/<profile>/chrome/zen-themes/<mod-id>/preferences.json

Notes:
- Profile folder names are machine-generated and can differ per install.
- You can usually copy a whole profile between machines, but it is not always clean or reliable.
- Avoid copying cache/lock/storage database files for a clean migration.
