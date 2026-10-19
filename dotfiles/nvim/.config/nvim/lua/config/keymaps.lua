-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Backspace deletes without yanking in normal and visual mode
vim.keymap.set({ "n", "x" }, "<BS>", '"_d', { desc = "Delete without yanking" })

-- Theme switching keymaps
local theme = require("config.theme")

vim.keymap.set("n", "<leader>1", function()
  theme.apply_theme("monochrome")
  vim.notify("Switched to Black Metal Immortal theme", vim.log.levels.INFO)
end, { desc = "Switch to Black Metal theme" })

vim.keymap.set("n", "<leader>2", function()
  theme.apply_theme("gruvbox")
  vim.notify("Switched to Gruvbox theme", vim.log.levels.INFO)
end, { desc = "Switch to Gruvbox theme" })

vim.keymap.set("n", "<leader>3", function()
  theme.apply_theme("tokyo-night")
  vim.notify("Switched to Tokyo Night theme", vim.log.levels.INFO)
end, { desc = "Switch to Tokyo Night theme" })

vim.keymap.set("n", "<leader>4", function()
  theme.apply_theme("catppuccin")
  vim.notify("Switched to Catppuccin Mocha theme", vim.log.levels.INFO)
end, { desc = "Switch to Catppuccin Mocha theme" })

vim.keymap.set("n", "<leader>5", function()
  theme.apply_theme("everforest")
  vim.notify("Switched to Everforest theme", vim.log.levels.INFO)
end, { desc = "Switch to Everforest theme" })

local _term_root = nil

local function toggle_terminal()
  if vim.bo.filetype ~= "snacks_terminal" then
    _term_root = LazyVim.root()
  end
  Snacks.terminal(nil, { cwd = _term_root or vim.uv.cwd(), count = 1 })
end

vim.keymap.set({ "n", "t" }, "<c-/>", toggle_terminal, { desc = "Toggle Terminal" })
vim.keymap.set({ "n", "t" }, "<c-_>", toggle_terminal, { desc = "which_key_ignore" })
