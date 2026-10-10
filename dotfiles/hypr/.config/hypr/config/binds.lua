local terminal = "foot"
local fileManager = "thunar"
local menu = "rofi -show drun"
local mainMod = "SUPER"

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("madsnake"))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.fullscreen({ mode = 0 }))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + D", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle-refresh.sh"))
hl.bind(
	mainMod .. " + B",
	hl.dsp.exec_cmd(
		"chromium --disable-background-timer-throttling --disable-backgrounding-occluded-windows --disable-renderer-backgrounding %U"
	)
)
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("foot -e nvim"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))

hl.bind(
	"F12",
	hl.dsp.exec_cmd(
		[[grim -g "$(slurp)" - | wl-copy && wl-paste > ~/Pictures/Screenshots/Screenshot-$(date +%F_%T).png | dunstify "Screenshot of the region taken" -t 1000]]
	)
)
hl.bind(
	"SHIFT + F12",
	hl.dsp.exec_cmd(
		[[grim - | wl-copy && wl-paste > ~/Pictures/Screenshots/Screenshot-$(date +%F_%T).png | dunstify "Screenshot of whole screen taken" -t 1000]]
	)
)

hl.bind("SHIFT + F11", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/screen_record.sh"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("foot -e ~/.config/hypr/scripts/battery-mode.sh"))
hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/clipboard_menu.sh"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/power-profiles.sh"))
hl.bind(mainMod .. " + CTRL + B", hl.dsp.exec_cmd("foot -e bluetui"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/power_menu.sh"))
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + SHIFT + L", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.focus({ workspace = "r-1" }))

hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.move({ workspace = "r-1" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Repeating media keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { repeating = true })

-- Locked media keys
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Switches
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("sleep 0.5 && hyprctl dispatch 'hl.dsp.dpms(\"off\")'"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.dpms(\"on\")'"), { locked = true })

-- Package list updater
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("foot -e $HOME/HyprVibe/bin/helpers/update-package-list.sh"))

-- Resize submap
hl.bind(mainMod .. " + Y", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
	hl.bind("H", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
	hl.bind("J", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
	hl.bind("K", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
	hl.bind("L", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
	hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Submap notifications
hl.on("keybinds.submap", function(name)
	if name == "resize" then
		hl.exec_cmd("notify-send -t 2000 'Resize Mode ON'")
	elseif name == "" then
		hl.exec_cmd("notify-send -t 2000 'Resize Mode OFF'")
	end
end)
