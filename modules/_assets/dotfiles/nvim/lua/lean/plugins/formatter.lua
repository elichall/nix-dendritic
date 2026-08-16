-- lua/lean/plugins/formatter.lua
return {
    {
        "stevearc/conform.nvim",
        event = { "BufWritePre" },
        cmd = { "ConformInfo" },
        keys = {
            {
                "<leader>fm",
                function() require("conform").format({ async = true, lsp_fallback = true }) end,
                mode = "n",
                desc = "Format Current Active Buffer",
            },
        },
        opts = {
            -- Mapping definitions
            formatters_by_ft = {
                lua = { "stylua" },
                python = { "ruff_format", "black", stop_after_first = true },
                cpp = { "clang-format" },
                c = { "clang-format" },
            },

            -- Global automated execution criteria on standard drive writes (:w)
            format_on_save = {
                timeout_ms = 500,
                lsp_fallback = true,
            },
        },
    },
}
