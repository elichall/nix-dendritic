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

-- Inside tmux, delegate COPY to tmux's own buffer instead of the local
-- xclip/wl-copy: those write to whatever machine nvim's process actually
-- runs on, which is useless when the session is a long-lived tmux session
-- being viewed over SSH from elsewhere. `load-buffer -w` forwards to
-- whichever client is currently attached via the same OSC52-write
-- mechanism tmux's own yank already uses (needs `allow-passthrough`, set
-- in tmux.nix) — write-only, so there's nothing to race.
--
-- PASTE deliberately avoids any active "ask the terminal what's in its
-- clipboard" query (tried both nvim's built-in OSC52 paste and tmux's
-- `refresh-client -l` — both round-trip through tmux's escape-sequence
-- parser, which is confirmed flaky upstream: tmux/tmux#3068, #4275,
-- neovim/neovim#28010/#29350; symptom was raw escape-response bytes
-- occasionally leaking into the buffer as text). Instead this just
-- reflects back whatever's already in the unnamed register, with zero
-- query/response — covers `p`/`"+p"` replaying content from a prior
-- yank/delete made inside nvim itself.
--
-- Confirmed interactively: for genuinely external content (e.g. from a
-- browser), use the terminal's own native paste gesture (bracketed paste
-- — a universal terminal standard, unaffected by OSC52/tmux config either
-- way) directly at the cursor, rather than `p`/`"+p"`. A PTY test showed
-- bracketed paste inserts text straight into the buffer WITHOUT touching
-- the unnamed register, so it and `p`/`"+p"` are two independent paths:
-- paste-at-cursor for external content, `p` for moving text around
-- within nvim itself (yank here, paste there) — both now work reliably
-- through tmux and over SSH, just via different mechanisms.
if vim.env.TMUX then
  local function pasteFromUnnamed()
    return {
      vim.split(vim.fn.getreg('"'), "\n"),
      vim.fn.getregtype('"'),
    }
  end

  vim.g.clipboard = {
    name = "tmux",
    copy = {
      ["+"] = { "tmux", "load-buffer", "-w", "-" },
      ["*"] = { "tmux", "load-buffer", "-w", "-" },
    },
    paste = {
      ["+"] = pasteFromUnnamed,
      ["*"] = pasteFromUnnamed,
    },
    cache_enabled = 0,
  }
end
