# HyprVibe Quickshell surfaces.
# Colors derive from colors.toml.

[bar]
background       = "{{ background }}"
background-alpha = 1.0
text             = "{{ foreground }}"
active           = "{{ red }}"
scale-with-font  = true
size-horizontal  = 26
size-vertical    = 28
icon-slot        = 26
icon-canvas      = 20
icon-font        = 15

[hyprland]
active-border            = "{{ accent }}"
active-border-foreground = "{{ foreground }}"

[controls]
normal-color        = "{{ foreground }}"
normal-fill-alpha   = 0.04
normal-border       = "{{ foreground }}"
normal-border-width = 1
normal-border-alpha = 0.4

hover-cursor-color        = "{{ foreground }}"
hover-cursor-fill-alpha   = 0.08
hover-cursor-border       = "{{ foreground }}"
hover-cursor-border-width = 1
hover-cursor-border-alpha = 0.25

focus-color        = "{{ foreground }}"
focus-fill-alpha   = 0.08
focus-border       = "{{ foreground }}"
focus-border-width = 1
focus-border-alpha = 0.25

selected-color        = "{{ foreground }}"
selected-fill-alpha   = 0.18
selected-border       = "{{ foreground }}"
selected-border-width = 0
selected-border-alpha = 1.0

pressed-fill-alpha   = 0.22
selection-fill-alpha = 0.35

[spacing]
scale = 1.0
scale-with-font = true

[font]
base-size = 14
family = "JetBrainsMono Nerd Font"

[popups]
background       = "{{ background }}"
background-alpha = 1.0
text             = "{{ foreground }}"
border           = "{{ accent }}"
border-alpha     = 1.0

[tooltip]
background       = "{{ background }}"
background-alpha = 0.97
text             = "{{ foreground }}"
border           = "{{ foreground }}"
border-alpha     = 1.0

[notifications]
background       = "{{ background }}"
background-alpha = 1.0
text             = "{{ foreground }}"
border           = "{{ accent }}"
border-alpha     = 1.0
countdown        = "{{ accent }}"

[launcher]
background                = "{{ background }}"
background-alpha          = 0.95
text                      = "{{ foreground }}"
border                    = "{{ foreground }}"
border-alpha              = 1.0
scrim                     = "{{ background }}"
scrim-alpha               = 0.5
selected-background       = "{{ foreground }}"
selected-background-alpha = 0.08
selected-text             = "{{ accent }}"
selected-border           = "{{ foreground }}"
selected-border-alpha     = 0.25

[menu]
background                = "{{ background }}"
background-alpha          = 1.0
text                      = "{{ foreground }}"
border                    = "{{ foreground }}"
border-alpha              = 1.0
scrim                     = "{{ background }}"
scrim-alpha               = 0.5
selected-background       = "{{ foreground }}"
selected-background-alpha = 0.08
selected-text             = "{{ accent }}"
selected-border           = "{{ foreground }}"
selected-border-alpha     = 0.25

[polkit]
background       = "{{ background }}"
background-alpha = 1.0
text             = "{{ foreground }}"
text-error       = "{{ red }}"
border           = "{{ accent }}"
border-error     = "{{ red }}"
border-alpha     = 1.0
scrim            = "{{ background }}"
scrim-alpha      = 0.5
accent           = "{{ accent }}"

[lock]
background       = "{{ background }}"
background-alpha = 0.8
text             = "{{ foreground }}"
placeholder      = "{{ dark_foreground }}"
text-error       = "{{ red }}"
border           = "{{ accent }}"
border-active    = "{{ accent }}"
border-error     = "{{ red }}"
border-alpha     = 1.0
selection        = "{{ accent }}"
selection-alpha  = 0.45

[image-picker]
scrim                   = "{{ background }}"
scrim-alpha             = 0.5
text                    = "{{ foreground }}"
selected-border         = "{{ accent }}"
selected-border-alpha   = 1.0
unselected-border       = "{{ foreground }}"
unselected-border-alpha = 0.28
