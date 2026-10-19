-- Catppuccin colorscheme
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = false,
      integrations = {
        blink_cmp = true,
        bufferline = true,
        cmp = true,
        flash = true,
        gitsigns = true,
        lualine = {},
        mason = true,
        mini = true,
        noice = true,
        notify = true,
        snacks = true,
        treesitter = true,
        which_key = true,
      },
    },
  },
}
