# OpenCode Power-User Implementation

> **STATUS: IMPLEMENTED (2026-08-12)** — `modules/programs/opencode.nix`
> (homeManager.opencode). Source plan: `opencode_poweruser.md`.

Scope: bring the opencode TUI config under Nix and implement the PDF ingestion
pipeline. Rebuild landed in the same switch as fastfetch + yazi.

## What was implemented

- **Global `/pdf` command** (PDF pipeline, §1): `home.packages` gains
  `poppler-utils` and `xdg.configFile."opencode/commands/pdf.md"` deploys a
  Nix-managed **global opencode command** (available in every directory and
  session — opencode scans `~/.config/opencode` for `{command,commands}/**/*.md`;
  project `.opencode/` dirs are per-tree). The template (`$ARGUMENTS`, verified
  in `command/index.ts`) instructs the agent to `pdftotext -layout` to a temp
  file and read it, escalate scanned PDFs via `pdftoppm` rasterization, use
  `pdfinfo` for metadata, and clean up.
  - Supersedes the earlier `ocread` `pkgs.writeShellApplication` wrapper (which
    spawned a nested headless `opencode run`); ocread is removed from the
    module. The command keeps the current session/conversation instead.
  - Home-scale, not `environment.systemPackages`: opencode is a pure user CLI
    with no system-level consumer (user directive).
- **tui.json Nix-owned**: `xdg.configFile."opencode/tui.json"` (`force = true`)
  with `theme = "system"` and `scroll_acceleration = { enabled = true }`.
  - Fixes a pre-existing bug: the live `tui.json` had `"enabled": "true"`
    (string). opencode's TUI validates `tui.json` as an exact Effect struct and
    **skips the whole file** on any parse failure (graceful warning), so the
    previous file was inert.

## Deviations from the source plan

| Plan item | Decision | Reason |
|---|---|---|
| §1 PDF pipeline | Implemented as global `/pdf` command | user request (global, not per-directory; no bash wrapper) |
| §1 pdf-parse Node plugin | Deferred → TODO stretch goal | the `/pdf` command covers PDF ingestion |
| §2 Custom commands | Dropped | user: "just an example" |
| §3 `"keybindings": "vim"` | Not implemented — unavailable | Verified against v1.15.10 source (`config.ts`, `tui-schema.ts`, `keybind.ts`, `CHANGELOG.md`), the live `opencode.ai/tui.json` schema, and repo-wide tree search: **no released opencode version has a vim keybinding mode**. The third-party `install-opencode.com` changelog claim is inaccurate. Default Emacs/readline bindings kept. |

## Pinning decision

**No pinning.** `keybindings = "vim"` was the only reason to consider
nixpkgs-unstable (opencode 1.16.2); since no release ships vim mode, the
current nixos-26.05 pin (opencode 1.15.10) stays.

## Verification

- In the TUI, `/pdf` appears in the command list from any directory; running
  `/pdf <real.pdf>` extracts and reads the text (scanned-PDF escalation noted).
- Launching the TUI shows **no** "skipping invalid tui config" warning
  (previously triggered by the string `"true"`).
- `./post-switch-smoke-test.sh` passes.
