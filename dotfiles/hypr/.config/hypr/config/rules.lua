hl.window_rule({
	match = { class = "code" },
	opacity = "0.8 1.0 override",
})

-- Smart Gaps
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })

-- Layer Rules for Blur
hl.layer_rule({ match = { namespace = "hyprvibe-bar" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0.5 })

hl.window_rule({
	match = { class = "^steam_app_.*$" },
	immediate = true,
	no_blur = true,
	no_shadow = true,
})
