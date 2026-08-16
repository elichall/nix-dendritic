-- lua/lean/core/keymaps.lua
local key = vim.keymap

-- ==============================================================================
-- INTERNAL WINDOW MANAGEMENT (Symmetrical to tmux.conf)
-- ==============================================================================
key.set("n", "<leader>|", "<cmd>vsplit<cr>", { silent = true, desc = "Split Window Vertically" })
key.set("n", "<leader>_", "<cmd>split<cr>", { silent = true, desc = "Split Window Horizontally" })
key.set("n", "<leader>x", "<cmd>close<cr>", { silent = true, desc = "Close Current Window" })

-- ==============================================================================
-- BUFFER & SYSTEM COMMANDS
-- ==============================================================================
key.set("n", "<leader>w", "<cmd>write!<CR>", { silent = true, desc = "Save Current Buffer" })
key.set("n", "<leader>s", "<cmd>update!<CR><cmd>source<CR>", { silent = true, desc = "Save and Source Active File" })
key.set("n", "<leader>q", "<cmd>write!<CR><cmd>quitall!<CR>", { silent = true, desc = "Quit Current Nvim Instance" })

-- ==============================================================================
-- REGISTER MANIPULATION (Yanking / Deleting to System Clipboard)
-- ==============================================================================
key.set({ "n", "v", "x" }, "<leader>y", '"+y', { silent = true, desc = "Yank Selection to System Clipboard" })
key.set({ "n", "v", "x" }, "<leader>p", '"+p', { silent = true, desc = "Paste From System Clipboard" })
key.set({ "n", "v", "x" }, "<leader>d", '"+d', { silent = true, desc = "Delete Selection to System Clipboard" })

-- ==============================================================================
-- ISOLATED PLUGIN INTERFACES
-- ==============================================================================
key.set("n", "<leader>e", "<cmd>Oil<CR>", { silent = true, desc = "Open Oil File Explorer" })
key.set('n', '<leader>f', function() MiniPick.builtin.files() end, { desc = "Pick Files Instantly" })
key.set('n', '<leader>gl', "<cmd>Pick grep_live<CR>", { desc = "Pick Grep Phrases Dynamically" })
key.set('n', '<leader>gs', "<cmd>Pick grep<CR>", { desc = "Pick Grep Phrases Statically" })
key.set("n", "<leader>h", "<cmd>Pick help<CR>", { silent = true, desc = "Fuzzy Find Help Configurations" })

-- Consistent Viewport Centering during high-velocity vertical searching
key.set("n", "<C-d>", "<C-d>zz", { silent = true, desc = "Scroll Downwards and Center Cursor" })
key.set("n", "<C-u>", "<C-u>zz", { silent = true, desc = "Scroll Upwards and Center Cursor" })
key.set("n", "n", "nzzzv", { silent = true, desc = "Next Search Match and Center Cursor" })
key.set("n", "N", "Nzzzv", { silent = true, desc = "Previous Search Match and Center Cursor" })

-- Visual Block Dragging (Symmetrical to shifting layout constructs)
key.set("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Translate Selected Block Downwards" })
key.set("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Translate Selected Block Upwards" })
