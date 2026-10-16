# HyprVibe Dynamic Theme for tmux
# Status bar general
set -g status on
set -g status-interval 1
set -g status-justify absolute-centre
set -g status-position bottom

# Colors
set -g status-style "bg={{ darker_background }},fg={{ foreground }}"

# Left side: Session name
set -g status-left-length 40
set -g status-left "#[fg={{ darker_background }},bg={{ accent }},bold] Session: #S #[fg={{ accent }},bg={{ darker_background }}]"

# Right side: Spacer to balance left side for proper centering
set -g status-right-length 40
set -g status-right ""

# Window list (center)
set -g window-status-separator ""

# Inactive windows (blend with status bar)
set -g window-status-format "#[fg={{ muted }},bg={{ darker_background }}] #I:#W "

# Active/current window
set -g window-status-current-format "#[fg={{ bright_foreground }},bg={{ selection }},bold] #I:#W #[fg={{ selection }},bg={{ darker_background }}]"

# Pane borders
set -g pane-border-style "fg={{ selection }}"
set -g pane-active-border-style "fg={{ accent }}"

# Message styling
set -g message-style "bg={{ selection }},fg={{ bright_foreground }}"
set -g message-command-style "bg={{ selection }},fg={{ bright_foreground }}"
