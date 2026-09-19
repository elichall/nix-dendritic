local opt = vim.opt

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

-- Inside tmux, delegate to tmux's own paste buffer instead of the local
-- xclip/wl-copy: those write to whatever machine nvim's process actually
-- runs on, which is useless when the session is a long-lived tmux session
-- being viewed over SSH from elsewhere. Terminal-agnostic on purpose (no
-- terminal name appears below) — `load-buffer -w` forwards to whichever
-- client is currently attached via the same escape mechanism tmux's own
-- yank already uses (needs `allow-passthrough`, set in tmux.nix), and
-- `refresh-client -l` asks that same attached client to push its real
-- clipboard into tmux's buffer before reading it back. Plain OSC52
-- query/response for paste (tried first) is unreliable through tmux — the
-- response has to travel back to nvim's stderr channel and often times
-- out or returns stale content (see neovim/neovim#28010, #29350).
if vim.env.TMUX then
  vim.g.clipboard = {
    name = "tmux",
    copy = {
      ["+"] = { "tmux", "load-buffer", "-w", "-" },
      ["*"] = { "tmux", "load-buffer", "-w", "-" },
    },
    paste = {
      ["+"] = { "bash", "-c", "tmux refresh-client -l; sleep 0.05; tmux save-buffer -" },
      ["*"] = { "bash", "-c", "tmux refresh-client -l; sleep 0.05; tmux save-buffer -" },
    },
    cache_enabled = 0,
  }
end
