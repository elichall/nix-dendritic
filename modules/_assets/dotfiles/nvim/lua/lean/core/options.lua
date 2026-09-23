local opt = vim.opt

-- Neovim's builtin filetype detection has no entry for .tpp (C++ template
-- implementation files, split from .hpp headers in some codebases) — with
-- no filetype match, syntax highlighting, treesitter, AND clangd's LSP
-- attachment (gated on filetype, see lean/plugins/lsp.lua) all silently
-- skip these files. Mapping the extension to the existing "cpp" filetype
-- fixes all three at once; no clangd-specific config needed since clangd's
-- own filetypes list already includes "cpp".
vim.filetype.add({ extension = { tpp = "cpp" } })

-- Time in milliseconds to wait for a mapped sequence to complete
opt.timeoutlen = 300
opt.ttimeoutlen = 0
opt.updatetime = 250

-- UI Layout
opt.number = true
opt.relativenumber = true
opt.splitright = true
opt.splitbelow = true
opt.winborder = "rounded"

-- Tabs & Indentation (Industry Standard Defaults)
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.autoindent = true

-- Autocompletion
opt.ignorecase = true
opt.smartcase = true

-- visual
opt.termguicolors = true
vim.g.markdown_folding = 1
opt.foldlevelstart = 99

-- other
opt.swapfile = false
opt.undofile = true
opt.signcolumn = "yes"
opt.incsearch = true
opt.wrap = false
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- System Clipboard Integration
-- Gracefully degrades if xclip/pbcopy/win32yank are missing
opt.clipboard = "unnamedplus"

-- No custom vim.g.clipboard here on purpose: Neovim's own built-in
-- provider (autoload/provider/clipboard.vim) already auto-detects
-- wl-copy/xclip/tmux correctly on its own — including a tmux fallback
-- using this exact load-buffer/refresh-client mechanism — PROVIDED
-- $DISPLAY/$WAYLAND_DISPLAY reflect whoever's actually attached right
-- now. That's handled by update-environment (tmux.nix) plus the precmd
-- refresh hook (cmdLine.nix) — see those for the actual fix. A prior
-- attempt duplicated nvim's own tmux provider manually here instead of
-- fixing the stale-env root cause; removed since it regressed the
-- already-reliable local wl-copy/xclip path on graphical hosts.
