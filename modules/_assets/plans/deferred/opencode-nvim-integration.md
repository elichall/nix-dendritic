# OpenCode + Neovim Integration — Research & Plan

## 1. What OpenCode Is (Context)

OpenCode is an open-source AI coding agent that runs in the terminal. It reads
and edits files, runs shell commands, and works through multi-step tasks on your
codebase. It has a client/server architecture — the TUI, desktop app, and IDE
extensions all talk to the same engine.

The current repo (`modules/programs/opencode.nix`) installs `pkgs.opencode` as a
Home Manager package, plus a custom `/pdf` command and `tui.json` config. No
Neovim integration exists yet.

---

## 2. opencode.nvim — The Neovim Plugin

**Repository:** [nickjvandyke/opencode.nvim](https://github.com/nickjvandyke/opencode.nvim)
(3.7k stars, MIT license, actively maintained)

### 2.1 What It Does

opencode.nvim wraps OpenCode's TUI and API into Neovim-native interfaces. It
does NOT reimplement the agent — it connects to an existing OpenCode server (or
starts one) and provides editor-aware context injection.

**Core features:**
- **Connect to any OpenCode server** — or start an integrated instance via
  `term://opencode --port`
- **Inject editor context** — cursor position, visual selection, full buffer, file
  path, LSP diagnostics. Placeholders like `@this`, `@buffer`, `@file`,
  `@diagnostics` get replaced with actual content when sent to the agent.
- **Input prompts with completions** — built-in prompts (`fix`, `implement`,
  `optimize`, `review`, `test`) plus custom ones
- **Accept/reject edits** — when OpenCode proposes a file edit, the plugin opens
  a side-by-side diff view (`:diffpatch`). You navigate hunks and accept/reject
  individually or all at once.
- **Autocmd events** — OpenCode events (`session.status`, `tui.command.execute`,
  etc.) are exposed as Neovim autocmds for custom workflows
- **Statusline integration** — show OpenCode connection status in lualine/etc.

### 2.2 Keybindings

| Key | Mode | Action |
|---|---|---|
| `<C-a>` | n, x | Ask OpenCode (injects `@this` context) |
| `<C-x>` | n, x | Select OpenCode prompt |
| `go` | n, x | Operator — append range to OpenCode |
| `goo` | n | Append current line to OpenCode |
| `<S-C-u>` | n | Scroll OpenCode up |
| `<S-C-d>` | n | Scroll OpenCode down |

Edit review (when OpenCode proposes changes):
| Key | Action |
|---|---|
| `da` | Accept entire edit |
| `dr` | Reject entire edit |
| `]c` / `[c` | Next/prev hunk |
| `dp` | Accept only hunk under cursor |
| `do` | Reject only hunk under cursor |

### 2.3 Integrations

- **snacks.nvim** — picker integration (send files to OpenCode from file picker),
  input enhancement, terminal management for the OpenCode server
- **blink.cmp** — completions in the Ask prompt via in-process LSP
- **lualine** — statusline showing OpenCode connection state
- **toggleterm** — alternative terminal wrapper for the OpenCode TUI

---

## 3. LSP Integration — How Agents See Errors

This is the key technical question. There are **two separate LSP systems** at
play:

### 3.1 OpenCode's Own LSP (Agent-Side)

OpenCode has a built-in LSP client that can start language servers and use their
diagnostics as feedback for the agent. When enabled:

1. OpenCode checks file extensions against enabled LSP servers
2. Starts the appropriate server if not already running
3. Collects diagnostics (errors, warnings) from the server
4. Feeds them back into the agent's context loop

**Built-in servers include:** bash-language-server, lua-ls, nixd, gopls,
pyright, rust-analyzer, clangd, typescript-language-server, and 30+ others.

**Configuration (opencode.json):**
```json
{
  "$schema": "https://opencode.ai/config.json",
  "lsp": true
}
```

Or selectively:
```json
{
  "lsp": {
    "nix": { "command": ["nixd"] },
    "bash": { "command": ["bash-language-server", "start"] },
    "lua": { "disabled": true }
  }
}
```

**Nix-specific note:** There's a known issue where `lsp_diagnostics` hangs with
`nixd` because nixd doesn't advertise `diagnosticProvider` in server
capabilities. OpenCode waits for a response to `textDocument/diagnostic` that
never comes. This may be fixed in newer versions, but it's worth testing.

**Important caveat from OpenCode docs:** *"Language servers can get out of sync,
use significant memory, vary by version or project, and slow down agent
workflows. In many projects it is better to have the agent run lint, typecheck,
or other diagnostic CLI tools directly."* The official recommendation is to
document diagnostic commands in `AGENTS.md` or skills rather than relying solely
on LSP.

### 3.2 opencode.nvim's In-Process LSP (Editor-Side)

The plugin provides an **in-process LSP** for the Ask prompt — this gives you
completions when typing in the OpenCode input buffer. This is separate from
OpenCode's agent-side LSP. It uses Neovim's native LSP client and works with
blink.cmp for completion.

### 3.3 The `@diagnostics` Placeholder

When you use `@diagnostics` in a prompt (or when the agent reads diagnostics),
OpenCode collects LSP diagnostics from its own LSP clients and injects them as
context. This means the agent can see:
- Syntax errors
- Type errors
- Lint warnings
- Unused variables
- Missing imports

The agent can then fix these automatically. The `fix` built-in prompt is
specifically designed for this: it sends `@diagnostics` to the agent and asks it
to resolve all reported issues.

### 3.4 `opencode debug lsp`

The CLI has a built-in debug command for LSP:
```bash
opencode debug lsp    # shows LSP server status, connected servers, diagnostics
```

This is useful for troubleshooting when diagnostics aren't appearing.

---

## 4. Nix Integration — How to Package This

### 4.1 What's Available in nixpkgs

| Package | Source | Version | Notes |
|---|---|---|---|
| `pkgs.opencode` | `pkgs/by-name/op/opencode/` | 1.16.2 | Already installed in the repo |
| `pkgs.vimPlugins.opencode-nvim` | `pkgs/applications/editors/vim/plugins/generated.nix` | 0.11.0 | Available, not yet installed |

Both are in nixpkgs — no external flake inputs needed.

### 4.2 Nixvim Module (If Using Nixvim)

Nixvim has a first-class `plugins.opencode` module with full options:
```nix
programs.nixvim.plugins.opencode = {
  enable = true;
  settings = {
    auto_reload = false;
    port = 8080;
  };
};
```

But the repo currently uses a **native Lua nvim config** (not Nixvim), so this
doesn't apply directly. The `extraPlugins` approach is what we'd use.

### 4.3 Integration Into the Dendritic Repo

**Option A: Add to existing `modules/programs/nvim.nix`**

The nvim module already owns the editor's user-level config. opencode.nvim is a
vim plugin — it belongs in the nvim aspect, not the opencode aspect.

```nix
# Inside flake.modules.homeManager.nvim:
{ config, pkgs, lib, ... }:
let
  # ... existing spell expansion code ...

  # opencode.nvim plugin
  opencode-nvim = pkgs.vimPlugins.opencode-nvim;
in
{
  # ... existing nixos.nvim and homeManager.nvim blocks ...

  home.packages = [ /* existing packages */ ];

  # Add to neovim plugin list
  programs.neovim.plugins = [ opencode-nvim ];

  # Configure via vim.g (the plugin's convention)
  xdg.configFile."nvim/lua/opencode-config.lua".text = ''
    vim.g.opencode_opts = {
      -- Configuration goes here
    }
  '';
}
```

**Option B: Separate `modules/programs/opencode-nvim.nix`**

Create a new aspect for the Neovim plugin specifically. This follows Rule 4
(per-module dependency self-containment) — the opencode-nvim plugin depends on
opencode being on PATH, which the `opencode` aspect already provides.

```nix
# modules/programs/opencode-nvim.nix
{ inputs, ... }: {
  flake.modules.homeManager.opencodeNvim = { pkgs, ... }: {
    programs.neovim.plugins = [ pkgs.vimPlugins.opencode-nvim ];

    # Keymaps via xdg.configFile or inline lua
    xdg.configFile."nvim/plugin/opencode-keymaps.lua".text = ''
      -- keymaps here
    '';
  };
}
```

**Recommendation:** Option A (add to existing nvim module). The plugin is
editor-specific configuration, not a standalone tool. Keeping it in the nvim
aspect follows the existing pattern where nvim.nix owns all editor plugins and
config. The opencode aspect (`opencode.nix`) owns the CLI tool and its
configuration; the nvim aspect owns editor integration.

### 4.4 LSP Server Availability on NixOS

OpenCode's agent-side LSP tries to auto-detect language servers on PATH. On
NixOS, servers need to be explicitly installed. The current repo has:
- `lua-language-server` — already on PATH (from nvim config)
- `bash-language-server` — already on PATH (from nvim config)
- `nixd` — would need to be added for Nix file diagnostics

For the agent to see LSP diagnostics on Nix files, `nixd` needs to be in
`home.packages` (or `environment.systemPackages`). This is a dependency of the
opencode aspect, not the nvim aspect.

**However:** The official recommendation is to use CLI tools (`nix flake check`,
`nix build --dry-run`) for Nix diagnostics rather than nixd, because nixd has
known issues with OpenCode's diagnostic polling. The agent can run these commands
directly via the `bash` tool and read the output.

---

## 5. Benefits & Tradeoffs

### 5.1 Benefits

| Benefit | Detail |
|---|---|
| **Stay in Neovim** | No context-switching to a separate terminal for AI assistance |
| **Editor context injection** | Agent sees cursor position, selection, buffer content — no copy-paste |
| **`@diagnostics` feedback** | Agent can see and fix LSP errors automatically |
| **Diff-based edit review** | Side-by-side diff view for proposed changes — granular accept/reject |
| **Autocmd integration** | React to agent events in your vim config (statusline, notifications) |
| **Works with existing setup** | opencode.nvim connects to the OpenCode server you already have running |
| **Nix-native** | Both packages (`opencode`, `opencode-nvim`) are in nixpkgs — no external inputs |

### 5.2 Tradeoffs / Cons

| Tradeoff | Detail |
|---|---|
| **Dual LSP confusion** | OpenCode's agent-side LSP and Neovim's editor-side LSP are independent. Diagnostics in the editor don't automatically appear in the agent context unless using `@diagnostics`. |
| **nixd hangs** | Known issue: `lsp_diagnostics` can hang with nixd. Workaround: use CLI diagnostic tools instead. |
| **Memory overhead** | Each LSP server consumes ~50-200MB RAM. Running nixd + lua-language-server + bash-language-server simultaneously adds up. |
| **Plugin maintenance** | opencode.nvim is a third-party plugin (not maintained by OpenCode core). Breaking changes possible. |
| **Nix store path opacity** | The plugin is installed from the Nix store — debugging plugin issues means navigating store paths. |
| **`OPENCODE_DISABLE_LSP_DOWNLOAD`** | On NixOS, OpenCode's auto-download of LSP servers may not work (no FHS). Best to install servers explicitly via Nix and disable auto-download. |

### 5.3 What the Agent Can Already Do Without LSP

OpenCode's agent doesn't *need* LSP to be useful. It can already:
- Run `nix build`, `nix flake check`, `nix eval` and parse errors
- Run `nixos-rebuild switch --flake` and read stderr
- Use `grep`/`glob` to find issues
- Read files and reason about Nix expressions
- Run lint/typecheck commands documented in `AGENTS.md`

LSP integration adds *real-time* diagnostics (the agent sees errors as they
appear in the editor), but the agent can already get the same information by
running commands. The value add is marginal for Nix code specifically.

---

## 6. Status: DEFERRED — Under Consideration

### Decision (2026-08-18)

The plugin is **not being added at this time**. The mental separation between
the agent and the code editor is a deliberate workflow choice, not a gap to be
filled.

**Rationale:** Describing context to the agent — file paths, what the code
does, what needs to change, and why — forces explicit thinking that solidifies
understanding. The friction of switching to a terminal split and articulating
the problem is a *feature*, not a cost. It's the difference between "the agent
fixes my code" and "I understand my code well enough to direct the agent
precisely."

The plugin's value is real (context injection, diff review, staying in-editor)
but it works against this workflow preference. Adding it would create a
temptation to shortcut the thinking that makes the agent interaction
productive.

### When to Revisit

- If the workflow shifts to larger application codebases (C++/Python) where
  editor context injection saves significant time over describing file paths
  and cursor positions
- If OpenCode gets proper Nix LSP support (nixd hang fixed) making
  `@diagnostics` useful for Nix code
- If the agent interaction pattern changes from "I direct, it executes" to
  "it suggests, I review" — the diff review feature becomes the primary
  value then

### Implementation Notes (Preserved for Future Reference)

When revisited, the integration path is straightforward:

1. Add `pkgs.vimPlugins.opencode-nvim` to `modules/programs/nvim.nix`
   (it's in nixpkgs — no flake input needed)
2. Configure keymaps (`<C-a>`, `<C-x>`, `go`, `goo`, `<S-C-u>`, `<S-C-d>`)
3. Enable LSP selectively in `opencode.json` (bash + lua, disable nixd)
4. Do NOT add `nixd` to home.packages solely for agent LSP — the hang
   issue and memory overhead aren't worth it; CLI tools are more reliable
5. Do NOT create a separate aspect module — it's editor config, belongs in
   the nvim aspect

### Open Questions (Deferred)

1. **snacks.nvim integration:** picker integration for sending files to
   OpenCode — relevant only if the plugin is adopted
2. **Custom prompts:** project-specific prompts (e.g. "nix-rebuild") —
   useful regardless of plugin adoption, could be done via CLI aliases
3. **Permission model:** auto-accept vs manual approval — only relevant
   with the plugin's diff review workflow
4. **Session persistence:** resume vs fresh start — CLI behavior, not
   plugin-dependent
