# Dynamic Theme Import for Dunst
[global]
    frame_color = "{{ accent }}"
    separator_color = "{{ accent }}"
    highlight = "{{ accent }}"

[urgency_low]
    background = "{{ background }}d9"
    foreground = "{{ foreground }}"
    frame_color = "{{ muted }}"
    highlight = "{{ muted }}"

[urgency_normal]
    background = "{{ background }}d9"
    foreground = "{{ foreground }}"
    frame_color = "{{ accent }}"
    highlight = "{{ accent }}"

[urgency_critical]
    background = "{{ background }}d9"
    foreground = "{{ foreground }}"
    frame_color = "{{ red }}"
    highlight = "{{ red }}"
