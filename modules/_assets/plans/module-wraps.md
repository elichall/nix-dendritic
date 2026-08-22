# Wrapper Modules — Homeless Dotfiles Plan

Origin: Vimjoyer, ["Homeless Dotfiles With Nix Wrappers"](https://www.youtube.com/watch?v=aNgujRXDTdE);
library: [Lassulus/wrappers](https://github.com/Lassulus/wrappers) (MIT, 334★, active).

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

## 6. Use cases (ranked)

1. **Guest toolkit** (coworker machine): `nix run github:<us>#nvim-guest` —
   full custom editor, zero $HOME mutation. Killer app.
2. **Foreign-host cleanliness**: non-NixOS boxes get tools purely from store;
   activation conflicts like the nvim permission incident become structurally
   impossible for wrapped tools.
3. **Iteration speed**: edit wrapper settings → `nix run .#x` immediately;
   no switch. Complements (not replaces) HM flow on owned hosts.
4. **Cross-platform reuse**: one wrapper module serves future
   darwin/server/WSL-flavor hosts (Rule 1 dividend).

## 7. Implementation phases

### P0 — Proof of concept: `nvim-guest` (smallest viable)
- Add input `wrappers` (+follows).
- `perSystem.packages.nvim-guest`: `wrapPackage` around our existing wrapped
  nvim closure with `env.NVIM_APPNAME = "nixdots"` + config files exposed at
  `xdg_config/nixdots/` inside the derivation (reuse `_assets/dotfiles/nvim`
  source-of-truth via symlinkJoin copy — do NOT duplicate trees).
- Acceptance: `nix run .#nvim-guest` on workstation AND on a foreign host with
  stock `~/.config/nvim` present → our config loads, theirs untouched,
  `:checkhealth` clean, state written under redirected dirs.

### P1 — Guest shell entry + toolkit expansion
- One `devshell-guest` script: exports NVIM_APPNAME/GIT_CONFIG_GLOBAL/
  STARSHIP_CONFIG/YAZI_CONFIG_HOME + evals zoxide/direnv/starship inits, so
  `exec` into it = full environment without rcfile edits.
- Wrap remaining toolbox tools (prefer upstream wrapperModules where present:
  git/starship/tmux/yazi/zellij/bat/btop/fastfetch; custom only for gaps).
- Expose as `flake.apps` for `nix run .#<name>` ergonomics.

### P2 — Host-side adoption (owned machines, optional per tool)
- Where a wrapper module's typed options beat raw HM options (validation,
  reuse across scales), swap the HM aspect body to consume
  `self.packages.<sys>.<tool>-wrapped` instead of `programs.<tool>` config.
- Gate each swap on byte-comparable behavior (drvPath diff discipline).

### P3 — Services & server hosts
- `wlib.modules.systemd` unit generation for server-side daemons later;
  pairs with server-architecture-decisions.md.

## 8. Risks / limitations

- **Double-module-system**: wrapper modules are their own evalModules island —
  they cannot read `config.host.*` scaffold directly; values pass through
  `.apply { ... }` call sites (keep call sites in dendritic modules, pass
  scaffold-derived values explicitly).
- Upstream churn: young library (288 commits); pin input, follow nixpkgs,
  re-vet on bump.
- Not every tool honors config-env vars; fallback = flags/symlink farms —
  audit per tool before promising isolation (table in §5).
- Desktop file patching defaults touch `share/applications` — fine in store.
- Guest mode ≠ security boundary: no filesystem confinement beyond what env
  vars achieve (tier ≤2). Real sandboxing remains bubblewrap/VM territory.

## 9. Open questions

- Naming: `*-guest` suffix vs `wrapped-*` prefix vs bare names under
  `.#apps`?
- Should P1 shell-entry live in `_lib/` (shared script builder) or a
  `modules/programs/guest-shell.nix` aspect?
- nvim long-term: stay on current HM-managed nvim + separate guest wrapper, or
  converge on ONE wrapped nvim consumed by BOTH HM hosts and guest mode
  (single source of truth, bigger refactor)?
- Does `noctalia` upstream wrapper module change our display-stack calculus
  when quickshell work resumes?

## 10. Validation checklist (per phase)

- [ ] Eval: warning-free, all four hosts unaffected (drvPaths identical until
      P2 adoption begins).
- [ ] Guest run on clean `$HOME` machine: tool launches with OUR config.
- [ ] Guest run alongside EXISTING configs (coworker scenario): zero bytes
      changed under their `$HOME/.config` (diff/snapshot before-after).
- [ ] State redirection verified: caches/state land in scratch subtree.
- [ ] Uninstall = exit process + delete scratch; nothing else lingers.

## Related docs

- `plans/completed/nvim-nixification-evaluation.md` — mnw status + successor note
- `plans/vm-sandbox-integration.md` — full isolation spectrum (tiers beyond env vars)
- `plans/server-architecture-decisions.md` — future systemd consumer
