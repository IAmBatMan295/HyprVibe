-- Suppress statusline on starter dashboard to prevent empty horizontal stripe
return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.globalstatus = true
      opts.options.theme = function()
        local cs = vim.g.colors_name or ""
        if cs == "forest-green" then
          return {
            normal = {
              a = { fg = "#0f1a14", bg = "#6bbf7a", gui = "bold" },
              b = { fg = "#a8e6a1", bg = "#1e2a24" },
              c = { fg = "#5f876f", bg = "#0f1a14" },
            },
            insert = {
              a = { fg = "#0f1a14", bg = "#89f6c4", gui = "bold" },
              b = { fg = "#a8e6a1", bg = "#1e2a24" },
              c = { fg = "#5f876f", bg = "#0f1a14" },
            },
            visual = {
              a = { fg = "#0f1a14", bg = "#9d7cd8", gui = "bold" },
              b = { fg = "#a8e6a1", bg = "#1e2a24" },
              c = { fg = "#5f876f", bg = "#0f1a14" },
            },
            replace = {
              a = { fg = "#0f1a14", bg = "#e06c75", gui = "bold" },
              b = { fg = "#a8e6a1", bg = "#1e2a24" },
              c = { fg = "#5f876f", bg = "#0f1a14" },
            },
            command = {
              a = { fg = "#0f1a14", bg = "#e5c07b", gui = "bold" },
              b = { fg = "#a8e6a1", bg = "#1e2a24" },
              c = { fg = "#5f876f", bg = "#0f1a14" },
            },
            inactive = {
              a = { fg = "#5f876f", bg = "#0f1a14" },
              b = { fg = "#5f876f", bg = "#0f1a14" },
              c = { fg = "#5f876f", bg = "#0f1a14" },
            },
          }
        elseif cs:find("catppuccin") or cs == "" then
          local ok, ctp = pcall(require, "catppuccin.utils.lualine")
          if ok then
            local ok_res, theme = pcall(ctp, "mocha")
            if ok_res and theme then
              return theme
            end
          end
          return "catppuccin-mocha"
        elseif cs == "immortal" then
          local ok, bm = pcall(require, "lualine.themes._black_metal")
          if ok and bm.get then
            local ok_res, theme = pcall(bm.get)
            if ok_res and theme then
              return theme
            end
          end
        end
        return "auto"
      end
      return opts
    end,
    config = function(_, opts)
      require("lualine").setup(opts)
      if
        vim.bo.filetype == "snacks_dashboard"
        or vim.bo.filetype == "dashboard"
        or vim.bo.filetype == "alpha"
        or (vim.fn.argc(-1) == 0 and vim.bo.filetype == "")
      then
        vim.o.laststatus = 0
      end
    end,
    init = function()
      local group = vim.api.nvim_create_augroup("HyprVibeDashboardStatusline", { clear = true })
      vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
        group = group,
        callback = function(ev)
          local ft = vim.bo[ev.buf].filetype
          if ft == "snacks_dashboard" or ft == "dashboard" or ft == "alpha" then
            vim.o.laststatus = 0
          else
            vim.o.laststatus = 3
          end
        end,
      })
    end,
  },
}
