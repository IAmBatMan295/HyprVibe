-- Everforest colorscheme (lazy-loaded; activated on demand)
return {
  {
    "sainnhe/everforest",
    lazy = true,
    priority = 1000,
    init = function()
      vim.g.everforest_background = "hard"
      vim.g.everforest_transparent_background = 0
      vim.g.everforest_enable_italic = true
      vim.g.everforest_better_performance = 1
    end,
  },
}
