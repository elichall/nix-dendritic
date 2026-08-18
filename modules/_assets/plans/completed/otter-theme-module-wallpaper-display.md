# Otter Theme Module Wallpaper Preview

## Status: IMPLEMENTED (2026-08-13)

Similar to the apps module which displays the app icon, the `th` otter module now
previews each theme's wallpaper (chafa) **and** its 16-color ANSI swatch.

## Mechanism

- **Swatch generation** (`modules/display/theme.nix`): new `swatchScript`
  (`theme-swatches`), invoked from `home.activation.initTheme` after the sync
  script on every activation. Loops `~/.local/share/theme/profiles/*.json`,
  resolves each profile's `ghostty_theme` to its full palette via headless
  ghostty (`XDG_CONFIG_HOME=$(mktemp -d) ghostty +show-config`, parse
  `palette = N=#HEX`), and writes
  `~/.local/share/theme/generated/previews/<profile>.swatch` (a single line of
  16 ANSI background blocks — no label/column text). Guarded (`|| continue` per
  profile) so a failed resolve degrades to wallpaper-only preview.
- **Preview command** (`modules/display/otter-launcher/config.toml`, `th`
  module): `--preview` first emits the kitty graphics delete-all sequence
  (`printf "\033_Ga=d,d=A\033\\"`) so each selection clears the previous image,
  reads `profiles/{1}.json` wallpaper via `jq -r .wallpaper`, renders with
  `chafa -s "${FZF_PREVIEW_COLUMNS:-34}x$((FZF_PREVIEW_LINES-3))"` (auto-sized
  to the preview pane via fzf's env vars; kitty-protocol real image in ghostty),
  then cats the matching `generated/previews/{1}.swatch`.
  `--preview-window=right:50%,wrap` (fits the 550x250 launcher).
- **fzf text-layout gotcha (kitty images)**: fzf lays out the preview *text*
  independently of the kitty image — chafa's `\e_G` output counts as a single
  invisible text line, so without padding the swatch text would be placed at the
  top of the pane, *under* the image. The command emits `$LN` blank lines after
  chafa so the swatch text lands below the image box (image = rows 0..LN-1,
  swatch at row LN+1).

## Contract (theme ↔ otter)

- `homeManager.theme` **owns** `profiles/*.json` (data) + `generated/previews/*.swatch`
  (derived artifacts, regenerated every activation).
- `homeManager.otterLauncher` **consumes** both (read-only); the `th` preview
  command references `@THEME_DIR@/profiles/{1}.json` and
  `@THEME_SWATCHES@/{1}.swatch` tokens (substituted by `mkOtterConfig`).
- Rule 4 deps: `jq` added to `homeManager.otterLauncher` `home.packages` +
  `otter-diagnose` check (`jq`). `chafa` already a declared dep (apps module).

## Scope notes

- Precomputed at activation (one loop over all 12 profiles), not on-demand in
  fzf → preview stays fast.
- No `services.state` item (out of scope); swatches live under the theme's
  impermanence-persist path `~/.local/share/theme/`.
- No Phase 3 DRY refactors, no fastfetch plan-doc note, no hyprland rule change.

## Bugfix postmortem (2026-08-13, post-deploy)

### Iteration 1 — "no palette swatch" for every theme

First deploy previewed "no palette swatch" for every theme. Root cause traced
read-only to the otter-launcher 0.7.6 source (`src/mod_exec.rs` + `src/main.rs`):
otter runs every module via
`run_module_command(module.cmd.replace("{}", &prompt_wo_prefix))` — it replaces
**every** bare `{}` in the cmd with the module argument (empty for the `th`
picker) before handing the string to `sh -c`. So `profiles/{}.json` →
`profiles/.json` and `previews/{}.swatch` → `previews/.swatch` → both `-f`
checks failed → "no palette swatch". fzf never saw the `{}` at all.

Earlier attempts (`-q '{}'` → `-q ''`, unquoting the `{}` paths) were red
herrings: otter was already replacing `-q '{}'` → `-q ''` and the unquoted
`{}` still became a path with the item missing. The changes were inert but
harmless.

**Fix**: use fzf's `{1}` (whole-line placeholder) for both preview paths.
Otter's exact-`{}` replace never matches, and fzf substitutes the selected
theme name. Single-token names make `{1}` equivalent to `{}`. Verified in a
tmux pty with the real `theme list --pure` pipeline: wallpaper + swatch
render on open, `themes (1/12)`.

### Iteration 2 — kitty-graphics preview: stale/stacked images + overflow

A follow-up change ran `chafa -s 18x18` (no `-f symbols`). ghostty supports
the kitty graphics protocol, so chafa emitted **real terminal images**:

1. **Stale/stacked images**: fzf clears its preview region with blank text,
   which cannot erase terminal-side images → each selection drew a new image
   on top of the previous ones.
2. **Overflow / "bounds"**: the fixed `18x18` size overflows the small preview
   pane (the launcher window is 550x250 → pane ≈ 26–34 cols x 12–15 rows),
   spilling over the swatch below.

**Fixes**:
- Emit the kitty delete-all sequence at the start of the preview command —
  `printf "\033_Ga=d,d=A\033\\"` — so every selection clears the prior image.
- Size chafa from fzf's env: `-s "${FZF_PREVIEW_COLUMNS:-34}x$((FZF_PREVIEW_LINES-3))"`
  (floored at 4 rows) so the image always fits the pane.
- **The swatch still rendered under the image** because fzf lays out preview
  text independently of the kitty image (chafa's `\e_G` = one invisible text
  line → fzf put the echo+swatch at the top of the pane, covered by the image
  box). Fixed by emitting `$LN` blank lines after chafa so the swatch text is
  pushed below the image box (rows 0..LN-1 → swatch at row LN+1).
- Swatch reduced to blocks-only (label + column numbers dropped).

The preview command must stay free of bare `{}` (iteration 1) and single
quotes are unavailable inside the `--preview '…'` wrapper, so the delete
sequence is `printf "…"` with the escapes doubled in TOML (`\\033`, `\\\\`).
