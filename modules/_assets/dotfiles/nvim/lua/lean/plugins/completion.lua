-- lua/lean/plugins/completion.lua
return {
  {
    "saghen/blink.cmp",
    version = "*", -- Leverages pre-compiled release binaries from GitHub tag streams
    event = "InsertEnter",
    dependencies = {
      "rafamadriz/friendly-snippets", -- Core snippets database engine
      "ribru17/blink-cmp-spell",
    },
    opts = {

      -- Explicitly drop the default keymaps layer to isolate our key actions
      keymap = {
        preset = "none",
        ["<Tab>"] = { "accept", "fallback" },
        ["<C-j>"] = { "select_next", "fallback" },
        ["<C-k>"] = { "select_prev", "fallback" },
        ["<S-Tab>"] = { "hide", "fallback" },
      },

      -- Visual element scaling
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "mono",
      },

      -- Component Data Providers
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          markdown = { "lsp", "path", "snippets", "buffer", "spell" },
          text = { "path", "snippets", "buffer", "spell" },
          tex = { "lsp", "path", "snippets", "buffer", "spell" },
          plaintex = { "lsp", "path", "snippets", "buffer", "spell" },
        },
        providers = {
          spell = {
            name = "Spell",
            module = "blink-cmp-spell",
            opts = {},
          },
        },
      },

      -- Target Behavior Adjustments
      completion = {
      --   -- Enforces strict case-insensitive prefix matching limits
      --   keyword = {
      --     range = "prefix",
      --   },

        list = {
          selection = {
            preselect = true,    -- Automatically highlights top candidate line item
            auto_insert = false, -- Prevents text line pollution until confirmed
          },
        },

        -- -- High-Contrast Symmetrical Window Definitions
        -- menu = {
        --   border = "rounded",
        --   draw = {
        --     columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
        --   },
        -- },
        -- documentation = {
        --   auto_show = true,
        --   auto_show_delay_ms = 200,
        --   window = { border = "rounded" },
        -- },
      },
    },
  },
}
