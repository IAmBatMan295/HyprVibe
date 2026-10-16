* {
    /* Semantic Rofi Palette */
    background: {{ background }}d9;
    background-alt: {{ lighter_background }};
    foreground: {{ foreground }};
    foreground-dim: {{ dark_foreground }};
    accent: {{ accent }};
    selection: {{ selection }};
    muted: {{ muted }};
    red: {{ red }};
    green: {{ green }};
    yellow: {{ yellow }};
    blue: {{ blue }};
    white: {{ white }};
    black: {{ black }};

    /* Menu Tokens */
    primary: {{ accent }};
    on-primary: {{ background }}d9;
    primary-container: {{ selection }};
    on-primary-container: {{ foreground }};
    on-surface: {{ foreground }};
    on-surface-variant: {{ muted }};
    outline: {{ accent }};
    outline-variant: {{ muted }};
    surface-container-high: {{ lighter_background }};
    error: {{ red }};
    error-container: {{ red }};
    on-error-container: {{ background }}d9;
}
