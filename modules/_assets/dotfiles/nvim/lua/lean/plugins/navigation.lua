return {
	{
		"christoomey/vim-tmux-navigator",
		lazy = false,
		init = function()
			vim.g.tmux_navigator_no_mappings = 1
		end,
		keys = {
			{ "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate Window Left" },
			{ "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate Window Down" },
			{ "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate Window Up" },
			{ "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate Window Right" },
		},
	},
}
