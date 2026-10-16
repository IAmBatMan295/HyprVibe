@define-color window_bg_color {{ background }};
@define-color window_fg_color {{ foreground }};
@define-color view_bg_color {{ background }};
@define-color view_fg_color {{ foreground }};
@define-color popover_bg_color {{ dark_background }};
@define-color popover_fg_color {{ foreground }};
@define-color accent_color {{ accent }};
@define-color accent_bg_color {{ selection }};
@define-color accent_fg_color {{ foreground }};
@define-color headerbar_bg_color {{ dark_background }};
@define-color headerbar_fg_color {{ foreground }};

/* Standard Selection Tokens */
@define-color theme_selected_bg_color {{ selection }};
@define-color theme_selected_fg_color {{ bright_foreground }};

/* Extended Libadwaita / GTK Semantic Tokens */
@define-color sidebar_bg_color {{ dark_background }};
@define-color sidebar_fg_color {{ foreground }};
@define-color card_bg_color {{ lighter_background }};
@define-color card_fg_color {{ foreground }};
@define-color dialog_bg_color {{ dark_background }};
@define-color dialog_fg_color {{ foreground }};
@define-color destructive_color {{ red }};
@define-color destructive_bg_color {{ red }};
@define-color destructive_fg_color {{ foreground }};
@define-color success_color {{ green }};
@define-color success_bg_color {{ green }};
@define-color success_fg_color {{ foreground }};
@define-color warning_color {{ yellow }};
@define-color warning_bg_color {{ yellow }};
@define-color warning_fg_color {{ background }};

button {
    background-color: {{ lighter_background }};
}
button:checked,
button:active {
    background-color: {{ selection }};
    border: 2px solid {{ accent }};
}

/* Sidebar, Places, TreeView, and ListView High-Contrast Selection */
treeview.view:selected,
treeview.view:selected:focus,
treeview.view:selected:backdrop,
treeview:selected,
treeview:selected:focus,
treeview:selected:backdrop,
row:selected,
row:selected:focus,
row:selected:backdrop,
placessidebar row:selected,
placessidebar row:selected:focus,
placessidebar row:selected:backdrop,
.shortcuts-pane treeview:selected,
.shortcuts-pane treeview:selected:focus,
.shortcuts-pane treeview:selected:backdrop {
    background-color: {{ selection }};
    color: {{ bright_foreground }};
}

/* Hover feedback for unselected rows */
treeview.view:hover:not(:selected),
row:hover:not(:selected),
placessidebar row:hover:not(:selected) {
    background-color: {{ lighter_background }};
}

/* Dynamic Accent Theming for Controls (Switches, Sliders, Progress, Tabs) */
switch:checked {
    background-color: {{ accent }};
    border-color: {{ accent }};
    color: {{ background }};
}
switch:checked > slider,
switch:checked slider {
    background-color: {{ background }};
    border: 1px solid {{ accent }};
    border-radius: 0px;
}

scale highlight,
scale > trough > highlight,
progressbar progress,
progressbar > trough > progress {
    background-color: {{ accent }};
    border-color: {{ accent }};
    border-radius: 0px;
}

/* Force Square Sliders (Kill Diamonds and Circles in GTK3 & GTK4) */
scale slider,
scale > trough > slider,
scale.horizontal.marks-before slider,
scale.horizontal.marks-after slider,
scale.vertical.marks-before slider,
scale.vertical.marks-after slider,
scale.horizontal.marks-before > trough > slider,
scale.horizontal.marks-after > trough > slider,
scale.vertical.marks-before > trough > slider,
scale.vertical.marks-after > trough > slider {
    background-image: none;
    background-color: {{ foreground }};
    border: 2px solid {{ accent }};
    border-radius: 0px;
    min-height: 16px;
    min-width: 16px;
    margin: -6px;
    box-shadow: none;
}
scale slider:hover,
scale > trough > slider:hover {
    background-color: {{ bright_foreground }};
    border-color: {{ accent }};
}
scale slider:active,
scale > trough > slider:active {
    background-color: {{ accent }};
    border-color: {{ accent }};
}

/* Notebook Active Tab Indicator */
notebook > header.top > tabs > tab:checked {
    box-shadow: inset 0 -3px {{ accent }};
    color: {{ bright_foreground }};
}
notebook > header.bottom > tabs > tab:checked {
    box-shadow: inset 0 3px {{ accent }};
    color: {{ bright_foreground }};
}
notebook > header.left > tabs > tab:checked {
    box-shadow: inset -3px 0 {{ accent }};
    color: {{ bright_foreground }};
}
notebook > header.right > tabs > tab:checked {
    box-shadow: inset 3px 0 {{ accent }};
    color: {{ bright_foreground }};
}
notebook > header tab:checked {
    color: {{ bright_foreground }};
}

/* Checkboxes and Radios */
check:checked,
checkbutton:checked check {
    background-color: {{ accent }};
    border-color: {{ accent }};
    color: {{ background }};
    border-radius: 0px;
}
radio:checked,
radiobutton:checked radio {
    background-color: {{ accent }};
    border-color: {{ accent }};
    color: {{ background }};
}
