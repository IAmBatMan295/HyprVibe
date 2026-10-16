"$schema" = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json"
version = 4
final_space = true
console_title_template = '{{ .Shell }} in {{ .Folder }}'

[[blocks]]
type = 'prompt'
alignment = 'left'
newline = true

  # PATH BLOCK - dynamic accent color matching theme
  [[blocks.segments]]
  type = 'path'
  style = 'diamond'
  foreground = '{{ accent }}'
  background = 'transparent'
  leading_diamond = ''
  trailing_diamond = ''
  template = '  {{ .Path }}'

  [blocks.segments.options]
  style = 'full'

  # GIT BRANCH with icon (only shows in git repos)
  [[blocks.segments]]
  type = 'git'
  style = 'plain'
  foreground = '{{ muted }}'
  background = 'transparent'
  template = ' {{ .HEAD }}{{ if or (.Working.Changed) (.Staging.Changed) }}*{{ end }} <fg={{ accent }}>{{ if gt .Behind 0 }}⇣{{ end }}{{ if gt .Ahead 0 }}⇡{{ end }}</>'

  [blocks.segments.options]
  branch_icon = '  '
  fetch_status = true
  fetch_upstream_icon = true

  # ARROW
  [[blocks.segments]]
  type = 'text'
  style = 'plain'
  foreground = '{{ accent }}'
  background = 'transparent'
  template = ' '
