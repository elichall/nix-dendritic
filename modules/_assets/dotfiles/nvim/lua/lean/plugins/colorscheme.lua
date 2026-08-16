-- lua/lean/plugins/colorscheme.lua
return {
  {
    "vague2k/vague.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "gmr458/vscode_modern_theme.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "D0nw0r/dark2026.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "rose-pine/neovim",
    lazy = false,
    priority = 1000,
  },
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "savq/melange-nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    optional = true,
    opts = { colorscheme = "lean_sync" },
  },
  {
    "lean_sync",
    dir = vim.fn.stdpath("config"), 
    lazy = false,
    priority = 1000,                
    config = function()
      -- Safely verify custom theme existence before execution
      local theme_ok, _ = pcall(vim.cmd, "colorscheme lean_sync")
      if not theme_ok then
        -- Native robust fallback theme bundled with Neovim
        vim.cmd("colorscheme rose-pine")
      end
    end,
  },
}
