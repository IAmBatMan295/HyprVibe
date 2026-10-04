hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpaper_changer.sh &")
    hl.exec_cmd("nm-applet &")
    hl.exec_cmd("waybar &")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1 &")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("mako &")
    hl.exec_cmd("hyprsunset &")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/battery.sh &")
    
    -- Clipboard Manager
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
