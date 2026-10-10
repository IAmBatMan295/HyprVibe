hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true
        }
    },
    device = {
        {
            name = "epic-mouse-v1",
            sensitivity = -0.5
        }
    }
})

-- Touchpad Gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
