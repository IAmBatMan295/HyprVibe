-- Suppress statusline on starter dashboard to prevent empty horizontal stripe
return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.globalstatus = true
      opts.options.theme = function()
        local cs = vim.g.colors_name or ""
        if cs:find("catppuccin") or cs == "" then
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
