# Dictionary Expansion: ltex-ls + Declarative Vim Spell Wordlist

Status: implemented (2026-08-16) — see modules/programs/nvim.nix and
`modules/_assets/dotfiles/nvim/spell/en.utf-8.add`.
Source: vault mining (`harvest-spellbad` over `~/Documents/me/vault`) + curated
~230 terms. Domain: scientific / physics / engineering (AFSD friction-stir,
meshfree/SPH, constitutive modeling, Gleeble/SHPB/EBSD, PINN/GPU physics-ML).

## Why

The workstation nvim config only had generic `en_us` spell + marksman/texlab
LSPs. Research/class notes are dense with domain jargon that vim flags as
misspelled. This doc preserves the spell `.add` research so the ltex path can
be dropped or re-routed later without rediscovery cost.

## Mechanism: two engines, one wordlist

Single source of truth: `_assets/dotfiles/nvim/spell/en.utf-8.add` (declarative,
repo is the truth; edit + rebuild, never `zg`).

### A. ltex-ls (grammar + spelling LSP, primary)
- nixpkgs `ltex-ls` v16.0.0 (Java), added to `home.packages`.
- Registered in `lua/lean/plugins/lsp.lua` `target_servers` with
  `settings.ltex.language = "en-US"` and `dictionary["en-US"]` loaded at
  startup from the wordlist (`stdpath("config")/spell/en.utf-8.add`).
- Pivot-if-heavy: ltex is a ~150MB JVM server. If it feels too heavy for
  everyday md/tex editing, disable `"ltex"` in `target_servers` and rely on
  mechanism B alone — the wordlist already covers both.

### B. Vim builtin spell via compiled wordfile (backbone)
- Derivation in `modules/programs/nvim.nix` performs a two-stage build:
  1. `expandWordlist` (pure Nix) reads the base `.add`, generates possessives
     (`'s` for every word) and regular plurals (`+s`/`+es`/`+ies`, with skips
     for adverbs `-ly`, words ending `-s`, plural-only irregulars, and digit-
     final words like `AA7050`), producing `en.utf-8.expanded`.
  2. The derivation copies the src tree to `$out`, injects the expanded file,
     then mkspells the EXPANDED set (via a temp-dir copy named `en.utf-8.add`)
     into `en.utf-8.add.spl` in `<rtp>/spell/` so vim auto-loads it.
  Output files: `spell/en.utf-8.add` (base, readable), `spell/en.utf-8.expanded`
  (base + inflections, consumed by ltex and harvest), `spell/en.utf-8.add.spl`.
- nvim is a BUILD-ONLY dependency — deliberately NOT on PATH. zg is a
  triage aid only (store is read-only; its adds never persist, by design).
- The whole tree (dotfiles + compiled spl) is installed read-only via
  `xdg.configFile."nvim"` (recursive symlink into the store; `force = true`
  since the store replaces the live dir — approved config overwrite).

## Spell mechanics (verified 2026-08-16)

- `has("spell")` = 1; base dict is nvim 0.12.4's
  `share/nvim/runtime/spell/en.utf-8.spl`.
- A compiled `.spl` loads ONLY from `<rtp>/spell/` (`:h spell-load`) — a
  top-level spell file next to the runtimepath root is ignored. Verified:
  with the file in the right place all curated words pass `spellbadword`,
  gibberish is still flagged.
- Words listed in the compiled add-file OVERRIDE main-dict flags: e.g.
  `feedstock` (main dict `local`) and `recrystallization` (main dict `local`)
  both pass once listed. Region suffix (`word/us`) also works but is not
  needed — a plain entry overrides.
- `'spellfile'` (the `zg` target) is empty by default and the `.add`-only
  route is NOT auto-loaded under headless `-l`; the compiled `.spl` path is
  the one that works declaratively.
- Lua gotchas (harvest): `vim.fn.argv()` is empty in `-l` mode — parse
  `vim.v.argv` past the `-l` entry; `vim.fn.spellbadword()` returns a LIST
  `{word, type}` — index `res[1]`, `res[2]` (types: `bad`, `local`, `rare`,
  `file`).

## Harvest tooling

`tools/harvest-spellbad` (in the nvim tree, shipped to
`~/.config/nvim/tools/`): frequency-sorted list of words vim would flag across
md/tex files in given dirs. Run:
`nvim -u NONE -l ~/.config/nvim/tools/harvest-spellbad [--min-count N] <dir>...`
Additives from it must be curated manually into `en.utf-8.add`. The tool is
strictly stdout-only (never writes anywhere) — additions can never be clobbered.
Known-word exclusion reads `en.utf-8.expanded` when present (covers all
generated inflections); falls back to inline plural rules matching nvim.nix.
Known words are stored lowercased so the tool stays vocabulary-focused and
does not report case violations.

## Wordlist format

- One word per line; **mixed-case entries are keep-case** (uppercase letters
  required at those positions — per `:h spell-wordlist-format`, a word with
  an upper-case letter only matches that letter at that position).
- `#` comment lines (also used by `zw` to mark a word wrong).
- Leading `_` marks a compound fragment (base of `-`-joined compounds).
- Do not touch the compiled `.spl` — it regenerates on every build.

### Case conventions (2026-08-16)
- **ACRONYMS in ALL-CAPS** (`AFSD`, `PDE`, `PINN`, `GPU`, `ISV`, `SPH`, …):
  enforced caps → `AFSDs`/`PDEs`/`PINNs` pass; lowercase `afsd`/`pde` flagged.
  Vault evidence confirms caps usage (190× SPH, 147× AFSD caps vs 2 lower).
- **Proper model names in Title-Case** (`Johnson-Cook`, `Zener-Hollomon`,
  `Navier-Stokes`, …): vault writes these Title-Case (20× Johnson-Cook, 10×
  Zener-Hollomon); lowercase entries fail the caps forms — a pre-existing
  gap fixed by Title-Case entries.
- **Common words stay lowercase** (`feedstock`, `recrystallization`, …):
  first-cap and all-caps match via the als→Als/ALS rule.
- `AA7050`/`AA7075` have digit-final → no plural generated (avoids `AA70500`).
  Possessive `AA7050's` still generated. Digit handling: parser regex and
  Lua patterns include `0-9`; `pluralOf` skips digit-final words.
