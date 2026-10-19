-- HyprVibe Dynamic Theme Sync
local theme = require("config.theme")

local function apply_theme(name)
  theme.apply_theme(name)
end

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        apply_theme()
      end,
    },
  },
  {
    dir = "~/.config/nvim",
    name = "hyprvibe-theme-sync",
    priority = 1000,
    config = function()
      -- Auto-reload when window receives focus
      vim.api.nvim_create_autocmd("FocusGained", {
        pattern = "*",
        callback = function()
          apply_theme()
        end,
      })

      -- File watcher for live theme reload
      local uv = vim.uv or vim.loop
      local watcher = uv.new_fs_event()
      if watcher then
        local watch_dir = vim.fn.expand("~/.local/state/hyprvibe/current")
        pcall(function()
          watcher:start(watch_dir, {}, vim.schedule_wrap(function()
            apply_theme()
          end))
        end)
      end

      -- Sync background on any ColorScheme change
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          theme.sync_terminal_bg()
        end,
      })

      -- Reset terminal default background on exit (OSC 111)
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          pcall(function()
            io.stdout:write("\x1b]111\x1b\\")
            io.stdout:flush()
          end)
        end,
      })

      -- Apply on startup
      apply_theme()
    end,
  },
}
