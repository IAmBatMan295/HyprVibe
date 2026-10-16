# HyprVibe dynamic btop theme template
# Main background, empty for terminal default, need to be empty if you want transparent background
theme[main_bg]="{{ background }}"

# Main text color
theme[main_fg]="{{ foreground }}"

# Title color for boxes
theme[title]="{{ foreground }}"

# Highlight color for keyboard shortcuts
theme[hi_fg]="{{ accent }}"

# Background color of selected items
theme[selected_bg]="{{ selection }}"

# Foreground color of selected items
theme[selected_fg]="{{ accent }}"

# Color of inactive/disabled text
theme[inactive_fg]="{{ muted }}"

# Color of text appearing on top of graphs, i.e uptime and current network graph scaling
theme[graph_text]="{{ foreground }}"

# Misc colors for processes box including mini cpu graphs, details memory graph and details status text
theme[proc_misc]="{{ cyan }}"

# Cpu box outline color
theme[cpu_box]="{{ selection }}"

# Memory/disks box outline color
theme[mem_box]="{{ selection }}"

# Net up/down box outline color
theme[net_box]="{{ selection }}"

# Processes box outline color
theme[proc_box]="{{ selection }}"

# Box divider line and small boxes line color
theme[div_line]="{{ selection }}"

# Temperature graph colors
theme[temp_start]="{{ green }}"
theme[temp_mid]="{{ yellow }}"
theme[temp_end]="{{ red }}"

# CPU graph colors
theme[cpu_start]="{{ green }}"
theme[cpu_mid]="{{ yellow }}"
theme[cpu_end]="{{ red }}"

# Mem/Disk free meter
theme[free_start]="{{ red }}"
theme[free_mid]="{{ yellow }}"
theme[free_end]="{{ green }}"

# Mem/Disk cached meter
theme[cached_start]="{{ blue }}"
theme[cached_mid]="{{ cyan }}"
theme[cached_end]="{{ green }}"

# Mem/Disk available meter
theme[available_start]="{{ green }}"
theme[available_mid]="{{ yellow }}"
theme[available_end]="{{ red }}"

# Mem/Disk used meter
theme[used_start]="{{ green }}"
theme[used_mid]="{{ yellow }}"
theme[used_end]="{{ red }}"

# Download graph colors
theme[download_start]="{{ cyan }}"
theme[download_mid]="{{ blue }}"
theme[download_end]="{{ magenta }}"

# Upload graph colors
theme[upload_start]="{{ yellow }}"
theme[upload_mid]="{{ orange }}"
theme[upload_end]="{{ red }}"

# Process box color gradient for threads, mem and cpu usage
theme[process_start]="{{ green }}"
theme[process_mid]="{{ yellow }}"
theme[process_end]="{{ red }}"
