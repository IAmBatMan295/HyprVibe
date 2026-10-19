-- HyprVibe Centralized Theme Engine for Neovim
local M = {}

M.theme_file = vim.fn.expand("~/.local/state/hyprvibe/current/theme.name")

M.theme_map = {
  ["catppuccin"] = "catppuccin-mocha",
  ["everforest"] = "everforest",
  ["gruvbox"] = "gruvbox",
  ["monochrome"] = "immortal",
  ["tokyo-night"] = "tokyonight-night",
}

M.plugin_map = {
  ["catppuccin-mocha"] = "catppuccin",
  ["catppuccin"] = "catppuccin",
  ["everforest"] = "everforest",
  ["gruvbox"] = "gruvbox",
  ["immortal"] = "black-metal",
  ["tokyonight-night"] = "tokyonight.nvim",
}

function M.get_hyprvibe_theme()
  if vim.fn.filereadable(M.theme_file) == 1 then
    local lines = vim.fn.readfile(M.theme_file)
    if #lines > 0 and lines[1] ~= "" then
      local name = vim.trim(lines[1])
      if M.theme_map[name] then
        return name
      end
    end
  end
  return "catppuccin"
end

function M.sync_terminal_bg()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  if normal and normal.bg then
    local hex = string.format("%06x", normal.bg)
    -- OSC 11: Set terminal default background color.
    -- [100]#rrggbb sets 100% opacity in Foot and URxvt to prevent any background bleed.
    pcall(function()
      io.stdout:write(string.format("\x1b]11;[100]#%s\x1b\\", hex))
      io.stdout:flush()
    end)
    -- Ensure MsgArea matches Normal background so command-line never shows terminal bg
    pcall(function()
      vim.api.nvim_set_hl(0, "MsgArea", { link = "Normal" })
    end)
  end
end

function M.apply_theme(name)
  local theme_name = name or M.get_hyprvibe_theme()
  local cs = M.theme_map[theme_name] or theme_name or "catppuccin-mocha"

  -- Ensure lazy plugin is loaded if needed
  local plugin_pkg = M.plugin_map[cs]
  if plugin_pkg and package.loaded["lazy"] then
    pcall(require("lazy").load, { plugins = { plugin_pkg } })
  end

  -- Theme-specific pre-hooks
  if cs == "everforest" then
    vim.g.everforest_background = "hard"
    vim.g.everforest_transparent_background = 0
    vim.g.everforest_enable_italic = true
    vim.g.everforest_better_performance = 1
  elseif cs == "immortal" then
    pcall(function()
      require("black-metal").setup({ theme = "immortal", variant = "dark", transparent = false })
    end)
  elseif cs == "catppuccin-mocha" or cs == "catppuccin" then
    vim.g.catppuccin_flavour = "mocha"
  end

  local ok, _ = pcall(vim.cmd.colorscheme, cs)
  if not ok then
    pcall(vim.cmd.colorscheme, "default")
  end

  M.sync_terminal_bg()

  -- Live reload Lualine if already loaded
  if package.loaded["lualine"] then
    pcall(function()
      require("lualine").setup()
    end)
  end
end

return M
