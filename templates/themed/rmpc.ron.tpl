#![enable(implicit_some)]
#![enable(unwrap_newtypes)]
#![enable(unwrap_variant_newtypes)]
(
    default_album_art_path: None,
    show_song_table_header: true,
    draw_borders: false,
    browser_column_widths: [20, 38, 42],

    background_color: None,
    modal_backdrop: true,

    text_color: "{{ foreground }}",

    header_background_color: None,
    modal_background_color: None,

    preview_label_style: (fg: "{{ accent }}"),
    preview_metadata_group_style: (fg: "{{ foreground }}"),

    tab_bar: (
        active_style: (fg: "{{ darker_background }}", bg: "{{ accent }}", modifiers: "Bold"),
        inactive_style: (fg: "{{ foreground }}", bg: None, modifiers: ""),
    ),

    highlighted_item_style: (fg: "{{ accent }}", modifiers: "Bold"),

    current_item_style: (fg: "{{ darker_background }}", bg: "{{ accent }}", modifiers: "Bold"),

    borders_style: (fg: "{{ accent }}", modifiers: "Bold"),
    highlight_border_style: (fg: "{{ accent }}"),

    symbols: (song: "󰝚 ", dir: " ", playlist: "󰲸 ", marker: "* ", ellipsis: "..."),
    
    progress_bar: (
        symbols: ["❚", "❚", "❚", "❚", "❚"],
        track_style: (fg: "{{ selection }}"),
        elapsed_style: (fg: "{{ accent }}"),
        thumb_style: (fg: "{{ accent }}"),
    ),

    scrollbar: (
        symbols: ["│", "█", "▲", "▼"],
        track_style: (fg: "{{ accent }}"),
        ends_style: (fg: "{{ accent }}"),
        thumb_style: (fg: "{{ accent }}"),
    ),
    
    song_table_format: [
        (
            prop: (kind: Property(Position), style: (fg: "{{ foreground }}"),
                default: (kind: Text("-"))
            ),
            width: "8%",
            alignment: Center,
        ),
        (
            prop: (kind: Property(Filename), style: (fg: "{{ muted }}"),
                highlighted_item_style: (fg: "{{ foreground }}", modifiers: "Bold"),
                default: (kind: Property(Filename), style: (fg: "{{ muted }}"),)
            ),
            width: "84%",
        ),
        (
            prop: (kind: Property(Duration), style: (fg: "{{ foreground }}"),
                default: (kind: Text("-"))
            ),
            width: "8%",
            alignment: Center,
        ),
    ],
    layout: Split(
        direction: Vertical,
        panes: [
            (
                size: "2",
                borders: "BOTTOM",
                pane: Pane(Tabs),
            ),
            (
                size: "3",
                borders: "BOTTOM",
                pane: Pane(Header),
            ),
            (
                size: "100%",
                borders: "NONE",
                pane: Pane(TabContent),
            ),
            (
                size: "3",
                borders: "TOP | BOTTOM",
                pane: Pane(ProgressBar),
            ),
        ],
    ),
    header: (
        rows: [
            (
                left: [
                    (kind: Text("[ "), style: (fg: "{{ accent }}", modifiers: "Bold")),
                    (kind: Property(Status(StateV2(
                        playing_label: "󰐊",
                        paused_label: "󰏤",
                        stopped_label: "󰓛",
                        playing_style: (fg: "{{ accent }}", modifiers: "Bold"),
                        paused_style: (fg: "{{ muted }}", modifiers: "Bold"),
                        stopped_style: (fg: "{{ muted }}", modifiers: "Bold"),
                    )))),
                    (kind: Text(" ]"), style: (fg: "{{ accent }}", modifiers: "Bold")),
                    (kind: Property(Widget(ScanStatus)))
                ],
                center: [
                    (kind: Property(Song(Title)), style: (fg: "{{ accent }}", modifiers: "Bold"),
                        default: (kind: Property(Song(Filename)), style: (fg: "{{ foreground }}", modifiers: "Bold"))
                    )
                ],
                right: [
                    (kind: Text("[ "), style: (fg: "{{ accent }}", modifiers: "Bold")),
                    (kind: Text("󰕾 "), style: (fg: "{{ accent }}", modifiers: "Bold")),
                    (kind: Property(Status(Volume)), style: (fg: "{{ foreground }}", modifiers: "Bold")),
                    (kind: Text("%"), style: (fg: "{{ muted }}")),
                    (kind: Text(" ]"), style: (fg: "{{ accent }}", modifiers: "Bold"))
                ]
            ),
            (
                left: [
                    (kind: Text("[ "), style: (fg: "{{ accent }}", modifiers: "Bold")),
                    (kind: Property(Status(Elapsed)), style: (fg: "{{ foreground }}", modifiers: "Bold")),
                    (kind: Text(" / "), style: (fg: "{{ muted }}")),
                    (kind: Property(Status(Duration)), style: (fg: "{{ foreground }}", modifiers: "Bold")),
                    (kind: Text(" │ "), style: (fg: "{{ selection }}")),
                    (kind: Property(Status(Bitrate)), style: (fg: "{{ foreground }}", modifiers: "Bold")),
                    (kind: Text(" kbps"), style: (fg: "{{ muted }}")),
                    (kind: Text(" ]"), style: (fg: "{{ accent }}", modifiers: "Bold"))
                ],
                center: [
                    (kind: Property(Song(Artist)), style: (fg: "{{ foreground }}", modifiers: "Bold"),
                        default: (kind: Text("Unknown Artist"), style: (fg: "{{ muted }}", modifiers: "Bold"))
                    ),
                    (kind: Text(" • "), style: (fg: "{{ muted }}")),
                    (kind: Property(Song(Album)), style: (fg: "{{ muted }}"),
                        default: (kind: Text("Unknown Album"), style: (fg: "{{ muted }}"))
                    )
                ],
                right: [
                    (kind: Text("[ "), style: (fg: "{{ accent }}", modifiers: "Bold")),
                    (kind: Property(Status(RepeatV2(
                            on_label: "󰑖", off_label: "󰑖",
                            on_style: (fg: "{{ accent }}", modifiers: "Bold"), off_style: (fg: "{{ muted }}"))))),
                    (kind: Text(" │ "), style: (fg: "{{ selection }}")),
                    (kind: Property(Status(RandomV2(
                            on_label: "󰒝", off_label: "󰒝",
                            on_style: (fg: "{{ accent }}", modifiers: "Bold"), off_style: (fg: "{{ muted }}"))))),
                    (kind: Text(" │ "), style: (fg: "{{ selection }}")),
                    (kind: Property(Status(ConsumeV2(
                            on_label: "󰮯", off_label: "󰮯", oneshot_label: "󰮯󰇊",
                            on_style: (fg: "{{ accent }}", modifiers: "Bold"), off_style: (fg: "{{ muted }}"))))),
                    (kind: Text(" │ "), style: (fg: "{{ selection }}")),
                    (kind: Property(Status(SingleV2(
                            on_label: "󰎤", off_label: "󰎦", oneshot_label: "󰇊", off_oneshot_label: "󱅊",
                            on_style: (fg: "{{ accent }}", modifiers: "Bold"), off_style: (fg: "{{ muted }}"))))),
                    (kind: Text(" ]"), style: (fg: "{{ accent }}", modifiers: "Bold")),
                ]
            ),
        ],
    ),
    browser_song_format: [
        (
            kind: Group([
                (kind: Property(Track)),
                (kind: Text(" ")),
            ])
        ),
        (
            kind: Group([
                (kind: Property(Artist)),
                (kind: Text(" - ")),
                (kind: Property(Title)),
            ]),
            default: (kind: Property(Filename))
        ),
    ],
)
