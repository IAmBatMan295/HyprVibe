-- Minimal Hyprland configuration for HyprVibe SDDM Wayland greeter.
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
hl.on("hyprland.start", function()
  hl.exec_cmd("hyprsunset -t 3700 &")
end)

-- Dynamic hardware monitor scaling & refresh rate
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.8 })
hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "auto", scale = 1.8 })

