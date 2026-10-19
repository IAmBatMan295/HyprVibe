-- Black Metal colorscheme (immortal)
return {
  {
    "metalelf0/black-metal-theme-neovim",
    name = "black-metal",
    lazy = true,
    priority = 1000,
    opts = {
      theme = "immortal",
      variant = "dark",
      transparent = false,
      alt_bg = false,
      term_colors = true,
      diagnostics = {
        darker = true,
        undercurl = true,
        background = true,
      },
      plugin = {
        lualine = {
          bold = true,
          plain = false,
        },
      },
    },
    config = function(_, opts)
      require("black-metal").setup(opts)
    end,
  },
}
