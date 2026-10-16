local active_border_color = "rgba({{ accent_strip }}ff)"
local inactive_border_color = "rgba({{ lighter_background_strip }}ff)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },
})
