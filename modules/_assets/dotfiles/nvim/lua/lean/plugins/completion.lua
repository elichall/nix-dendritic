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

      -- Feature-contributed sources are merged at runtime by init.lua's
      -- pcall → lean.research pattern. Each feature module returns a
      -- completions table that gets spliced into providers/per_filetype.

      completion = {
        list = {
          selection = {
            preselect = true,
            auto_insert = false,
          },
        },
      },
    },
  },
}
