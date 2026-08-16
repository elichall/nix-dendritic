-- lua/lean/plugins/treesitter.lua
return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = function()
      pcall(function()
        local ts = require("nvim-treesitter")
        if type(ts.update) == "function" then
          ts.update()()
        else
          vim.cmd("TSUpdate")
        end
      end)
    end,
    event = { "BufReadPost", "BufNewFile" },
    -- Configuration fields are now declared directly here for O(1) lazy-loading execution
    opts = {
      ensure_installed = { 
        "cpp", 
        "python", 
        "cmake",
        "bash",
        "c",
        "lua",
        "vim",
        "vimdoc",
        "query",
        "markdown",
        "markdown_inline",
      },
      sync_install = false,
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },
      indent = {
        enable = true,
      },
    },
    config = function(_, opts)
      -- Migrated to the modern Neovim 0.12 initialization handler
      pcall(function()
        local ts = require("nvim-treesitter")
        if type(ts.setup) == "function" then
          ts.setup(opts)
        end
        if opts.ensure_installed and type(ts.install) == "function" then
          ts.install(opts.ensure_installed)()
        end
      end)
    end,
  },
}
