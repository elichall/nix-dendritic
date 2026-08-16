return {
  -- Oil.nvim: Directory Tree as a Native Text Buffer
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- Visual indicators
    lazy = false, -- Load immediately to handle directory arguments at launch
    config = function()
      require("oil").setup({
        default_file_explorer = true,
        columns = { "icon" },
        view_options = {
          show_hidden = true,
        },
        keymaps = {
          ["<Esc>"] = "actions.close",
        },
      --   -- Symmetrical window manipulation inside the explorer
      --   keymaps = {
      --     ["g?"] = "actions.show_help",
      --     ["<CR>"] = "actions.select",
      --     ["<C-v>"] = "actions.select_vsplit",
      --     ["<C-x>"] = "actions.select_split",
      --     ["<C-p>"] = "actions.preview",
      --     ["<C-c>"] = "actions.close",
      --     ["-"] = "actions.parent",
      --     ["_"] = "actions.open_cwd",
      --     ["`"] = "actions.cd",
      --     ["~"] = "actions.tcd",
      --     ["gs"] = "actions.change_sort",
      --     ["gx"] = "actions.open_external",
      --     ["g."] = "actions.toggle_hidden",
      --     ["g\\"] = "actions.toggle_trash",
      --   },
      })

      -- Global toggle mapping matching standard file interaction
      -- vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })
    end,
  },

  -- Mini.pick: Low-Footprint Fuzzy Finder
  {
    "echasnovski/mini.pick",
    version = false, -- Use latest release branch
    event = "VimEnter",
    config = function()
      local pick = require("mini.pick")
      pick.setup({
        options = {
          use_cache = true,
        },
      })

      -- -- Leader-spaced mappings for telemetry search loops
      -- vim.keymap.set("n", "<leader><space>", function() pick.builtin.files() end, { desc = "Fuzzy Find Files" })
      -- vim.keymap.set("n", "<leader>/", function() pick.builtin.grep_live() end, { desc = "Live Grep Workspace" })
      -- vim.keymap.set("n", "<leader>fb", function() pick.builtin.buffers() end, { desc = "Fuzzy Find Active Buffers" })
      -- vim.keymap.set("n", "<leader>fh", function() pick.builtin.help() end, { desc = "Fuzzy Find Help Tags" })
    end,
  },
}
