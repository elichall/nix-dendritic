# Wrapper Modules — Homeless Dotfiles Plan

Origin: Vimjoyer, ["Homeless Dotfiles With Nix Wrappers"](https://www.youtube.com/watch?v=aNgujRXDTdE);
library: [Lassulus/wrappers](https://github.com/Lassulus/wrappers) (MIT, 334★, active).

**Strategy (2026-08-22, user direction):** wrappers power ONE simple
"one size fits all" plug-and-play host (§7) plus selective smart per-item
adoptions (nvim first). NOT a bulk refactor of existing aspects — the island
constraint makes that an overhaul, deliberately late-game.

## 1. Motivation (why NOW)

**Concrete trigger (2026-08-22):** standalone-HM activation on a foreign host died
with *permission denied* while overwriting pre-existing nvim files (older,
non-Nix-managed copies). User resolved by manual deletion — acceptable once, but
the friction class is real:

- Coworker/shared machines: we want OUR tooling (nvim/git/starship/tmux/yazi)
  WITHOUT clobbering their dotfiles or building dual-config messes.
- Foreign-distro hosts: anything Nix-built should live entirely in the store;
  `$HOME` stays untouched ("clean host" property).
- Iteration loop: test module config changes via `nix run` without
  rebuild/switch cycles.

## 2. What "homeless dotfiles" means

Term origin: Nix builds run with `HOME=/homeless-shelter` (a nonexistent home)
so builds can't read/write real user state. The pattern applies the same idea
to TOOLS AT RUNTIME: an executable reads its configuration from store paths or
redirected locations instead of `$HOME/.config`, so it composes with any host
without mutating it.

Isolation tiers, weakest→strongest:

| Tier | Mechanism | Example |
|---|---|---|
| 0 | none (HM-managed dotfiles) | current `homeManager.*` aspects — writes into `$HOME` at activation |
| 1 | per-tool env var / flag pointing at a store config | `NVIM_APPNAME`, `GIT_CONFIG_GLOBAL`, `STARSHIP_CONFIG`, `tmux -f` |
| 2 | full XDG redirection (`XDG_CONFIG_HOME` → store tree) | one wrapper family for many tools |
| 3 | namespace sandbox (bubblewrap) | out of scope here (see vm-sandbox-integration.md spectrum) |

Tier 1–2 are what wrapper modules automate.

## 3. The library: Lassulus/wrappers

"A Nix library to create wrapped executables via the module system." Two APIs +
a registry:

### 3.1 Low-level: `wrappers.lib.wrapPackage`
Args: `package`, `exePath`, `binName`, `runtimeInputs`, `env` (attrset),
`flags` (attrset; `true`=bare flag, string=with arg, false/null=omitted),
`flagSeparator` (`" "` default, `"="` supported), `args` (raw argv override),
`preHook`/`postHook`, `aliases`, `filesToPatch` (desktop-file Exec=/Icon=
rewriting by default), `filesToExclude`, `passthru`.
Preserves all original outputs (man/completions) via `lndir` symlink farm.

### 3.2 High-level: `wrappers.lib.wrapModule`
Module-system factory: declare typed `options`, map them onto
`config.package`/`flags`/`env`; consume with
`myWrapper.apply { …settings… }.wrapper`. Supports `extendModules`-style
chaining (`first.apply { more }`). Custom type `wlib.types.file` =
`{ content }` → `pkgs.writeText` path. Optional `wlib.modules.systemd`
generates user AND system unit files from the same config.

### 3.3 Prebuilt registry: `wrappers.wrapperModules.*`
**47 modules** upstream. Overlap with our toolbox/desktop stack:

| Ours already | Prebuilt upstream |
|---|---|
| git, gh, starship, tmux, yazi, zellij, zsh | ✅ all present |
| bat, btop, fastfetch | ✅ present |
| ghostty, kitty, alacritty, foot | ✅ present |
| waybar, hyprland/hypridle/hyprlock, niri, noctalia | ✅ present |
| rofi, fuzzel, mako, sway* family, zathura, skim | ✅ present |
| **nvim** | ❌ absent (see §5.1) |
| opencode | ❌ absent |

## 4. Architectural fit (dendritic alignment)

This library is almost eerily aligned with our Rule 1 (aspect-oriented
modules): ONE wrapper module definition, consumed at ANY scale —

```nix
# hypothetical modules/editors/niri-wrap.nix shape
{ inputs, self, ... }: {
  perSystem.packages.niri-wrapped =
    inputs.wrappers.wrapperModules.niri.apply {
      pkgs = ...;
      settings = { ... };
    }.wrapper;

  flake.modules.nixos.niri = { pkgs, ... }: {
    programs.niri.package = self.packages.${pkgs.stdenv.hostPlatform.system}.niri-wrapped;
  };
  # homeManager/darwin consumers reuse the SAME wrapped derivation
}
```

- Config lives ONCE in the wrapper module (typed options, eval-time checks),
  not duplicated across nixos/HM/darwin aspect bodies.
- `perSystem` exposure gives guest mode for free: `nix run .#<tool>` works on
  ANY machine with Nix — no clone of dotfiles, no activation.
- Input hygiene: `wrappers.url = "github:Lassulus/wrappers";` with
  `inputs.wrappers.inputs.nixpkgs.follows = "nixpkgs"` (tier-1 rule).
- Non-goal conflict check: this does NOT replace HM aspect config for hosts we
  OWN — it adds a parallel consumption path where $HOME must stay pristine.

## 5. Per-tool reality check (isolation mechanics)

| Tool | Isolation mechanism | Notes |
|---|---|---|
| nvim | `NVIM_APPNAME=<name>` redirects config/data/state/state-dirs cleanly | **best-in-class**; no upstream wrapper module — write ours via `wlib.wrapModule` or plain `wrapPackage` env injection. Our completed nvim-nixification-evaluation already flagged mnw as ⚠ maintenance-mode with "successor is nix-wrapper-modules" — convergence point |
| git | `GIT_CONFIG_GLOBAL` + `GIT_CONFIG_SYSTEM` env vars | prebuilt module exists — verify which mechanism it uses |
| starship | `STARSHIP_CONFIG` | prebuilt exists |
| yazi | `YAZI_CONFIG_HOME` | prebuilt exists |
| tmux | no appname var → `-f <store-conf>` flag + `TMUX_TMPDIR` | prebuilt exists; check flag plumbing |
| zsh/zellij | ZDOTDIR / `--config` | prebuilt exist |
| shell-integration trio (zoxide/direnv/fzf hooks) | init-script based — wrapping binaries does NOT isolate rc integration | guest mode needs ONE self-contained shell-entry script exporting all env vars + eval-ing inits; see P1 |

**Writable-state caveat (critical honesty):** store paths are read-only.
Tools that WRITE caches/state (nvim undo/plugins, direnv cache, starship
nothing, git nothing) need those redirected too: `XDG_CACHE_HOME`/
`XDG_DATA_HOME` → e.g. `${XDG_CACHE_HOME:-$HOME/.cache}/nixguest/<tool>` or
`$TMPDIR`. Read-only-config tools work pure-store; stateful tools need the
two-path split (config=store, state=writable scratch). This keeps the HOST
clean even in guest mode (state confined to one scratch subtree, deletable).

## 6. Host taxonomy: upstage vs plug-and-play

Two fundamentally different deployment contracts for Nix-managed tooling on a
machine:

| | **Upstage hosts** | **Plug-and-play host** |
|---|---|---|
| Output | `homeConfigurations.*` (activation) | `apps.*` / `packages.*` (nix run/shell) |
| `$HOME` contract | activation WRITES into `$HOME` — takes over user config | zero `$HOME` writes, ever |
| Deployment ritual | activate (+ backup dance, conflicts possible) | `git clone && nix run .#…` — literally it |
| Hosts today | workstation, laptop, wsl, linux (standalone HM) | **toolbox.nix** (proposed) |
| Failure mode | overwrite conflicts (2026-08-22 nvim incident) | none — structurally cannot conflict |

Upstage hosts remain right for machines we OWN long-term. The plug-and-play
class covers everything else: borrowed machines, quick containers/VMs,
pre-configured foreign boxes, "just let me edit this file properly" moments.

## 7. The toolbox homeless host ("smart" host)

One host whose entire deliverable is a **wrapped, adaptive, homeless
toolchain**: clone → build → run, on any Linux box, leaving the host exactly
as found (state confined to one deletable scratch subtree).

### 7.1 Adaptivity without `config.host.*`

Wrapper modules are evalModules islands — they cannot read our scaffold. The
toolbox host therefore gets adaptivity from OUTSIDE the wrapper evals, in
three layers:

1. **Build-time detection shim** (small shell script, mirrors legacy
   toolbox's `setup.sh` + `TOOLBOX_USER --impure` precedent): detects
   WSL (`/proc/version`), session protocol (`$WAYLAND_DISPLAY`/`$DISPLAY`),
   then passes results as explicit args into `.apply { … }` call sites.
   Detection lives in ONE place; wrappers stay pure.
2. **Runtime sniffing in the enter-script**: last-mile decisions (clipboard
   backend selection, win32yank availability) made when the process starts,
   not when the derivation builds.
3. **Wrapper-level cross-env defaults**: each tool wrapped so its baseline
   works everywhere (e.g. nvim clipboard providers ordered wayland→x11→
   win32yank).

### 7.2 Scope discipline ("sparingly and smartly")

Because every adaptation point is explicit plumbing across the island
boundary, blanket coverage would be a full-repo overhaul (late-game).
Instead: the toolbox host ships the CORE toolbox group first
(nvim/git/starship/tmux/yazi/zellij/bat/btop/fastfetch + shell entry),
each item added only when its isolation mechanics are verified (§5 table).
nvim is the exemplar of the "smart sparingly" rule — highest value, native
`NVIM_APPNAME`, custom wrapper justified. Items whose HM aspect can't map to
wrapper mechanics stay upstage-only.

### 7.3 Relationship to existing hosts

- Shares SOURCES (`_assets/dotfiles/nvim`, theme paths) — never duplicates
  trees.
- Does NOT share HM `programs.*` bodies (those write rcfiles by design);
  wrapper configs are parallel definitions fed from the same assets.
- Long-term question (open): could toolbox-homeless eventually REPLACE the
  wsl/linux standalone-HM hosts for throwaway machines? Probably yes for
  quick sessions; upstage wins wherever persistence matters.

## 8. Implementation phases

### P0 — Proof of concept: `nvim-guest` (smallest viable, the exemplar)
- Add input `wrappers` (+follows).
- `perSystem.packages.nvim-guest`: `wrapPackage` around our existing wrapped
  nvim closure with `env.NVIM_APPNAME = "nixdots"` + config files exposed at
  `xdg_config/nixdots/` inside the derivation (reuse `_assets/dotfiles/nvim`
  source-of-truth via symlinkJoin copy — do NOT duplicate trees).
- Acceptance: `nix run .#nvim-guest` on workstation AND on a foreign host with
  stock `~/.config/nvim` present → our config loads, theirs untouched,
  `:checkhealth` clean, state written under redirected dirs.

### P1 — Toolbox homeless host MVP (`.#apps.toolbox-enter`)
- ONE enter-app: PATH composed of wrapped core tools + exported env vars
  (NVIM_APPNAME / GIT_CONFIG_GLOBAL / STARSHIP_CONFIG / YAZI_CONFIG_HOME /
  TMUX_TMPDIR) + eval'd shell inits (zoxide/direnv/starship).
- Detection shim feeds build-time args (WSL? protocol?); enter-script does
  runtime last-mile selection.
- Scratch-state standard: all redirected writable dirs under one root,
  e.g. `${XDG_CACHE_HOME:-$HOME/.cache}/toolbox-homeless/`.
- Acceptance: on a pristine foreign machine — clone, `nix run .#toolbox-enter`,
  full working environment; `find $HOME -newer <marker>` shows ONLY the scratch
  subtree; exit + delete = host pristine.

### P2 — Opportunistic coverage growth
- Promote tools one-by-one into the toolbox host where §5 mechanics verified;
  prefer upstream prebuilts (git/starship/tmux/yazi/zellij/bat/btop/fastfetch);
  custom wrappers only for gaps (nvim done in P0, opencode later if wanted).
- Optional per-tool `.#apps.<tool>` singles for no-shell quick use.
- Selective upstage-side adoption stays ALLOWED but is per-item judgment
  ("sparingly and smartly"): a wrapped tool replaces its HM aspect body only
  when the typed wrapper options earn their keep — gated on byte-comparable
  behavior (drvPath diff discipline). NOT a bulk refactor; the island
  constraint (§8) makes wholesale migration an overhaul, deliberately out of
  scope.

### P3 — Services & server hosts
- `wlib.modules.systemd` unit generation for server-side daemons later;
  pairs with server-architecture-decisions.md.

## 8. Risks / limitations

- **Double-module-system / island constraint**: wrapper modules cannot read
  `config.host.*`; every adaptation point is explicit plumbing at `.apply`
  call sites. This is WHY the toolbox host starts small and grows
  opportunistically (§7.2) — blanket coverage would be a full-repo overhaul,
  explicitly late-game, not a refactor.
- Upstream churn: young library (288 commits); pin input, follow nixpkgs,
  re-vet on bump.
- Not every tool honors config-env vars; fallback = flags/symlink farms —
  audit per tool before promising isolation (table in §5).
- Desktop file patching defaults touch `share/applications` — fine in store.
- Homeless ≠ security boundary: no filesystem confinement beyond what env
  vars achieve (tier ≤2). Real sandboxing remains bubblewrap/VM territory.

## 9. Open questions

- Enter-app home: `_lib/` script builder vs `modules/programs/toolbox-enter.nix`
  aspect? (lean `_lib` — it builds derivations, not HM config.)
- nvim long-term: current plan = TWO consumers of one source tree
  (`_assets/dotfiles/nvim` feeds both HM hosts and P0 guest wrapper). True
  convergence into ONE wrapped binary for both is cleaner but bigger — defer.
- Does `noctalia` upstream wrapper module change our display-stack calculus
  when quickshell work resumes?
- Could toolbox-homeless eventually REPLACE wsl/linux standalone-HM hosts for
  throwaway machines? (persistence needs decide; revisit after P1 field use)

## 10. Validation checklist (per phase)

- [ ] Eval: warning-free, all four hosts unaffected (drvPaths identical until
      selective adoption begins).
- [ ] Guest run on clean `$HOME` machine: tool launches with OUR config.
- [ ] Guest run alongside EXISTING configs (coworker scenario): zero bytes
      changed under their `$HOME/.config` (diff/snapshot before-after).
- [ ] State redirection verified: caches/state land in scratch subtree.
- [ ] Uninstall = exit process + delete scratch; nothing else lingers.
- [ ] Toolbox host detection matrix: WSLg / native wayland / x11 / headless
      each yield correct clipboard + session behavior from ONE build.

## Related docs

- `plans/completed/nvim-nixification-evaluation.md` — mnw status + successor note
- `plans/vm-sandbox-integration.md` — full isolation spectrum (tiers beyond env vars)
- `plans/server-architecture-decisions.md` — future systemd consumer
