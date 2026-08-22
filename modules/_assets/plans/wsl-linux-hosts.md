# Plan — WSL + Linux (non-NixOS) Host Configuration

Status: ACTIVE · Created 2026-08-21
Scope: bring the `wsl` and `linux` hosts live using the existing dendritic
architecture. macOS stays deferred (no hardware). Server stays a stub.

---

## 1. Research Findings

### 1.1 Toolbox autopsy (`~/Projects/toolbox`) — what worked, what broke

The toolbox project deployed standalone Home Manager configs to WSL and Ubuntu
(`homeConfigurations.<user>@<host>` via `homeManagerConfiguration`). Its git
history and `TODO.md` document real deployment failures worth inheriting as
requirements:

| # | Finding | Consequence for this plan |
|---|---------|--------------------------|
| T1 | **WSLg sets `WAYLAND_DISPLAY`/`DISPLAY`** even though there is no real Wayland session. Tools auto-detect "Wayland" and spawn native binaries. | yazi yank/cut exited 127 (wl-copy/xclip missing). On WSL we must ship **wl-clipboard AND xclip** regardless of platform branching. |
| T2 | **`wslview` missing** — md-view.nvim failed with E475 "'wslview' is not executable". | WSL host needs `pkgs.wslu` (provides wslview) in `home.packages`. |
| T3 | **nvim autopaste bug**: win32yank's input buffer replayed stale content into nvim on open. Fixed with shell alias `nvim = "win32yank -i </dev/null && nvim"` plus an explicit nvim p override. | WSL host gets the drain-buffer alias in `cmdLine`; verify whether current nvim versions still need it before keeping permanently. |
| T4 | **win32yank not in their closure** — installed manually via curl + sudo tee to `/usr/local/bin` (unmanaged, outside Nix). | Use `pkgs.win32yank` from nixpkgs (verify presence early; fallback = tiny fetchurl wrapper derivation). Never hand-place binaries. |
| T5 | **blesh flag dead code** — `enableBlesh = true` was set in the data attrset but no module consumed it. Silent no-op. | Confirms the repo's Option-A stance: config values must be *consumed* by feature modules, not parked in data bags. |
| T6 | **`homeManagerConfiguration` demands explicit identity** — since HM ≥ 20.09, omitting `home.username` / `home.homeDirectory` / `home.stateVersion` fails ("option home.homeDirectory was accessed but has no value"). | The linux host file must carry an explicit identity module. |
| T7 | **`targets.genericLinux.enable = true`** is what makes HM integrate with a foreign distro (XDG data dirs, mime, fontconfig paths). | Required in the linux host's base module. |
| T8 | **Activation collides with pre-existing dotfiles** (`.bashrc`, `.profile`, …) — HM aborts or clobbers. Their `setup.sh` backs these up before activating. | Our bootstrap script must back up non-symlink rcfiles before first activation. |
| T9 | **No systemd under plain HM-on-WSL**: no user services, no proper session management, sudo-installed binaries, manual font copying to Windows Terminal. This is the root friction that made toolbox WSL feel second-class. | **Decision D1 below** — abandon the HM-only WSL approach entirely. |
| T10 | Their `setup.sh` host detection is solid: `/proc/version` microsoft grep → WSL; `/etc/os-release` ID=nixos → NixOS; ID=ubuntu; Darwin → macOS. Identity prompt persisted to `~/.config/toolbox/identity`. | Detection logic reused in our bootstrap script (§6). |

### 1.2 Web research — current best practice (checked Aug 2026)

| Source | Takeaway |
|--------|----------|
| [NixOS-WSL docs](https://nix-community.github.io/NixOS-WSL/how-to/nix-flakes.html) + repo (latest release 2511.7.1, Mar 2026) | Recommended path for WSL is a **regular `nixosSystem`** with `inputs.nixos-wsl.nixosModules.default`, `wsl.enable = true`, `wsl.defaultUser = "<user>"`. Gives full NixOS (systemd, user management, our whole nixos registry) inside WSL2. Exposes `system.build.tarballBuilder` to produce distributable `.wsl` tarballs (import needs WSL ≥ 2.4.4). Interop-affecting changes require `wsl --shutdown` from Windows. |
| mightyiam/**dendritic** (pattern spec) | Every file is a top-level module; lower-level configs are option values; values shared through top-level `config`, not `specialArgs`. Exactly this repo's architecture — nothing to migrate, just extend. |
| kclejeune/**system** | Validates exposing one HM module tree **both** nested-in-NixOS *and* as standalone `homeConfigurations` for foreign Linux — precisely our workstation/linux duality. |
| nixos-unified / denix | Autowiring frameworks exist but are unnecessary here — `import-tree` + the 2-level registry already covers discovery. Not adopted (would violate Rule 2's spirit by adding a second convention). |

### 1.3 Current repo state (grounding)

- Stubs `modules/hosts/{wsl,ubuntu,macos}.nix`: empty `flake.homeConfigurations.{wsl,ubuntu,macos}` via `homeManagerConfiguration { modules = [ ]; }`.
- Untracked draft `modules/options/hostOpt.nix`: declares `host.isWsl` +
  `host.buildDeskopEnv` (typo) in **nixos scope only**, registered nowhere.
- flake inputs: nixpkgs 26.05, home-manager release-26.05, wlctl,
  otter-launcher, noctalia. **No nixos-wsl input yet.**
- Groups available for reuse: `homeManager.toolbox` (cmdLine/git/tmux/nvim/yazi/opencode),
  `homeManager.utils`, `homeManager.options`, `nixos.cmdLine`, `homeManager.clipboard`
  (currently unconditional `pkgs.wl-clipboard`).
- TODO stretch goal #222 already sketches this work ("fix specialArgs →
  extraSpecialArgs…") — superseded by this plan (options pattern replaces
  specialArgs bridging entirely).

---

## 2. Architecture Decisions

### D1 — WSL = full NixOS via nixos-wsl, NOT standalone Home Manager
`nixosConfigurations.wsl` with `inputs.nixos-wsl.nixosModules.default`.
The stub flips from `homeConfigurations.wsl` → `nixosConfigurations.wsl`.

Rationale: toolbox's T9 shows HM-only WSL degrades every system-level concern
(no systemd units, unmanaged binaries, no user accounting). nixos-wsl restores
the full NixOS substrate so the existing dendritic aspects apply unmodified.
This is also upstream's documented recommendation.

### D2 — Linux (non-NixOS) = standalone Home Manager
`homeConfigurations.linux` reusing `homeManager.*` aspects verbatim. Identity
module inline in the host file (T6) with `targets.genericLinux.enable = true`
(T7). This is the kclejeune-validated dual-use of one HM tree.

### D3 — Host flags: Option-A options module, dual-scope, scaffold breadth
`modules/options/hostOpt.nix` exports both `flake.modules.nixos.optionsHost`
and `flake.modules.homeManager.optionsHost` declaring the same `host.*` tree
(same names, per-class declarations — mirrors the `mime.nix` dual-scope
precedent).

**IMPLEMENTED (2026-08-21), superseding the original minimal-flag draft:**
the user chose scaffold-breadth over strict YAGNI — the tree covers the
*possibility space* of a host (`isNixos`, `isWsl`, `displayProtocol`, `shell`,
`identity.{username,email,gitUsername,gitEmail}`) so template hosts need only
overrides. Defaults encode standard practice. Cross-scope default sharing is
via a file-level `stdPractice` let (cross-eval isolation makes config-level
linking impossible); semantic inheritance stays same-scope
(`gitUsername ← username`). NO per-host mkDefault bridges in host files —
cascade machinery deferred until a real nixos-side override need appears.
First consumer wired: `homeManager.git`. Details: contract C28, decision #56.

### D4 — Gating strategy: imports for exclusion, flags for intra-aspect branching
- Headless hosts simply don't import display/base groups (host-file decision,
  visible in one place).
- Shared aspects that ARE imported everywhere read `config.host.isWsl` for
  internal branching (clipboard packages, cmdLine alias).
- No aspect ever imports another aspect to learn the platform (Rule 2/3).

### D5 — Identity hardcoded per host file (no env-var indirection)
`elichall`, matching workstation/laptop. Toolbox's `TOOLBOX_USER` + `--impure`
build pattern is explicitly rejected (breaks pure eval; identity belongs to the
host file per Option A).

### D6 — nixos-wsl pinned with `inputs.nixpkgs.follows`
Single-channel policy like every other input. Fallback documented: if the
nixos-wsl × nixpkgs-26.05 combination breaks evaluation, remove `follows` and
let nixos-wsl carry its own pin (accepting a second channel) — decided at
first-eval time, §7.

### D7 — `ubuntu.nix` renamed to `linux.nix`
"Ubuntu" is one distro; `targets.genericLinux` makes the host distro-generic.
Stub has zero content to preserve. macOS stub untouched.

### D8 — What is deliberately NOT ported from toolbox
- `toolbox.*` data attrset via `extraSpecialArgs` → replaced by options modules.
- `TOOLBOX_USER` env detection → D5.
- Per-host duplicated module lists across `host/*.nix` files → registry+groups.
- blesh integration (T5: never actually worked; bash users here are on stock
  readline + starship; revisit only if requested).
- Their nvim/theme/tmux/yazi module bodies (superseded by this repo's richer
  aspects).

---

## 3. Target Shape

### `modules/options/hostOpt.nix` — DONE (see contract C28, decision #56)
Dual-scope `host.*` tree with shared `stdPractice` let-in defaults; registered
via both classes' `options` groups in `modules/groups/options.nix`; first
consumer (`homeManager.git`) wired; workstation + laptop validated with
drvPaths byte-identical to pre-change baseline.

### `modules/hosts/wsl.nix` — DELIVERED (standalone HM; nixos-wsl flavor deferred)
`homeConfigurations.wsl` via `homeManagerConfiguration`: imports
options/toolbox/utils/clipboard + inline base block (`host.isWsl = true`,
`host.isNixos = false`, identity via `config.host.identity.username`,
genericLinux, fonts in home.packages). The original nixos-wsl sketch is kept
below for the future full-NixOS flavor:

```nix
# FUTURE: nixosConfigurations.wsl with inputs.nixos-wsl.nixosModules.default,
# wsl.enable = true, wsl.defaultUser, inline identity — see decision #56/#57
# context and D1 rationale below.
```

Excluded by omission: `base` group (networkmanager/pipewire/bluetooth/tlp/
fwupd/microcode all conflict-with or idle-under WSL — nixos-wsl manages
internals), `desktop`/`desktopExp` groups, `hardwareConfig` (no
hardware-configuration.nix exists for WSL; nixos-wsl supplies the filesystem).

### `modules/hosts/linux.nix` (replaces ubuntu.nix)
```nix
{ inputs, self, ... }: {
  flake.homeConfigurations.linux =
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        # identity + genericLinux (T6/T7) — inline, NOT homeManager.main (D9)
        { ... }: {
          home.username = "elichall";
          home.homeDirectory = "/home/elichall";
          home.stateVersion = "26.05";
          targets.genericLinux.enable = true;
          fonts.fontconfig.enable = true;
          programs.home-manager.enable = true;
          host.isWsl = false;   # explicit for clarity
        }
        self.modules.homeManager.options
        self.modules.homeManager.toolbox
        self.modules.homeManager.utils
        self.modules.homeManager.clipboard
      ];
    };
}
```

### Aspect edits (flag consumers) — DONE
- `modules/system/clipboard.nix`: `displayProtocol` selects wl-clipboard/xclip;
  `isWsl` adds vendored win32yank (absent from pin → fetchzip v0.0.4,
  `stripRoot = false`, dual-name install) + native wslview shim (wslu REMOVED
  from nixpkgs — archived upstream) + xclip (WSLg exposes x11 too). Decision #57.
- `modules/programs/cmdLine.nix`: nvim drain-buffer alias under
  `lib.optionalAttrs config.host.isWsl` (T3; removal-candidate review after
  first real WSL session).
- `modules/programs/cmdLine.nix` shell-integration matrix (user-authored):
  per-consumer `mkIntegrations` lists match HM-pin reality — fzf supports
  bash/zsh/fish only; zoxide+direnv lack ion; starship/home.shell full set.
  Scaffold-only: zsh/fish/nushell enum-valid, only bash ships a shell body
  (comment-only guard per user choice). Review fix: `nixos.cmdLine` inner
  function must declare `config` — dynamic path
  `programs.${config.host.shell}` otherwise binds to FLAKE scope and kills
  every NixOS eval ('attribute host missing'). Laptop wired with
  `self.modules.nixos.options` (first host to need it beyond workstation).
- Prerequisite fix: `flake-parts.nix` imports
  `inputs.home-manager.flakeModules.home-manager` (undeclared-output collision).
- No theming aspects imported on either host (user direction: full-feature
  parity first, theming later).

### D9 — Why hosts inline identity instead of importing `main` aspects
`nixos.main` carries bootloader(systemd-boot)/zram/flatpak/fonts/tmpfiles —
several of which are wrong-or-redundant under WSL (bootloader especially:
nixos-wsl forbids a normal boot.loader layout). `homeManager.main` carries
pointerCursor/portal-gtk assumptions of a graphical session. Rather than
thread `isWsl` conditionals through `main`s (coupling the flagship hosts'
baseline to platforms they'll never run on), headless hosts declare their own
minimal identity inline. Host files are the one sanctioned place for this
(AGENTS.md §4 example does the same). If a third headless host appears,
revisit extraction into a `headless` preset group.

---

## 4. Implementation Order

| Step | Task | Gate |
|------|------|------|
| 0 | Verify `pkgs.win32yank` exists in nixpkgs 26.05 pin (`nix eval`) | eval |
| 1 | ~~Rewrite `modules/options/hostOpt.nix`; register in `modules/groups/options.nix`; wire workstation~~ **DONE** (dual-scope scaffold + git consumer; see C28/#56) | ✅ drvPaths identical |
| 2 | ~~Add `nixos-wsl` input~~ **DEFERRED** — user direction (2026-08-21): both hosts ship toolbox-style standalone HM first; nixos-wsl flavor is a later addition. Prereq discovered instead: import `home-manager.flakeModules.home-manager` in flake-parts wiring | ✅ both hosts build |
| 3 | ~~Rewrite `hosts/wsl.nix` per §3~~ **DELIVERED AS STANDALONE HM** (user direction supersedes D1 for now): `homeConfigurations.wsl` with `host.isWsl = true`; nixos-wsl flavor deferred. Builds clean | ✅ |
| 4 | Branch `clipboard.nix` + `cmdLine.nix` on host flags **DONE**: clipboard branches on `displayProtocol`+`isWsl` (win32yank vendored — absent from pin; wslu REMOVED from pin → native wslview shim, decision #57); cmdLine adds nvim drain alias under `isWsl`. Workstation drvPaths byte-identical to baseline | ✅ |
| 5 | ~~Rename ubuntu→linux, implement §3 shape~~ **DONE** as standalone HM (`homeConfigurations.linux`, identity via scaffold). Builds clean | ✅ |
| 6 | Full validation sweep (§7) + smoke expectations doc | all green |
| 7 | Docs pass (§8): decisions, contracts, maintenance guide, README, AGENTS.md alignment, TODO.md | — |
| 8 | Bootstrap script `setup-host.sh` (§6) | `shellcheck` + dry-mode run on workstation |

Real deployment (steps requiring the target machines) is USER-RUN:
- WSL: import official `nixos.wsl` tarball → clone → `sudo nixos-rebuild switch --flake ~/.nix#wsl` → `wsl --shutdown` cycle.
- Linux: install Nix → clone → build+activate `.#homeConfigurations.linux`.

## 5. Known Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| nixos-wsl incompatible with nixpkgs 26.05 pin via `follows` (D6) | First-eval gate (step 3); fallback = drop `follows`, accept second channel. Decision recorded in decisions.md either way. |
| Hidden conflicts when nixos-wsl meets our few imported nixos aspects (e.g. `nix.settings` tmpfiles, nix-ld) | WSL host imports almost nothing from the registry besides HM groups; any conflict surfaces at step-3 eval, fixed by trimming the inline block, never by weakening workstation config. |
| `programs.fastfetch`/other HM aspects assume graphical session | Not imported on headless hosts (groups chosen accordingly: toolbox+utils only). |
| win32yank absent from nixpkgs pin | Step-0 check; fallback fetchurl wrapper (pinned release v0.0.4 zip, `autoPatchelfHook` not needed — ships static exe; mark executable, wrap in `$out/bin`). |
| nvim autopaste bug may be obsolete in current nvim/win32yank | Keep alias initially (harmless one-shot drain); flag in maintenance guide for removal-candidate review after first real WSL session. |
| HM activation collision on fresh linux box (T8) | Documented in bootstrap script: backs up non-symlink `.bashrc`/`.profile`/`.zshenv` before first activate. |

## 6. Bootstrap Script Sketch (`setup-host.sh`, repo root)

Detection (from toolbox, proven): `/proc/version` microsoft → wsl;
`/etc/os-release` ID=nixos → nixos; else linux; Darwin → print "deferred".

Modes:
- `--detect` — print detected class, exit (used in CI-ish checks).
- linux: ensure nix (`command -v nix` || official installer prompt) → ensure
  flakes experimental-feature in `~/.config/nix/nix.conf` → backup rcfiles
  (non-symlink only, `.pre-nix` suffix) → `nix build .#homeConfigurations.linux.activationPackage`
  → `./result/activate` → remind: relogin for shell integration.
- wsl: assumes official NixOS-WSL tarball already imported (prints exact
  PowerShell commands if not: `wsl --install --no-distribution`, download
  release asset, double-click/import, `wsl -d NixOS`) → inside: enable flakes
  in `/etc/nix/nix.conf` → clone → `sudo nixos-rebuild switch --flake ~/.nix#wsl`
  → remind: `wsl --shutdown` from Windows for interop changes.
- Optional stretch: `install-windows-fonts` subcommand copying nerd fonts from
  nix profile to `/mnt/c/Users/<win>/AppData/Local/Microsoft/Windows/Fonts`
  (Windows Terminal rendering), resolving `%USERPROFILE%` via cmd.exe interop
  like toolbox did.

## 7. Validation Checklist

```bash
# parse + registry
nix-instantiate --parse $(git ls-files '*.nix') > /dev/null
nix eval .#modules --json | jq '...'          # registry keys present

# WSL host builds on this machine (x86_64-linux == x86_64-linux)
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --no-link

# linux host evaluates to real activation drv
nix eval .#homeConfigurations.linux.activationPackage.drvPath

# isolation proof: workstation/laptop drvPaths byte-identical to pre-change
nix eval .#nixosConfigurations.workstation.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.laptop.config.system.build.toplevel.drvPath

# flag plumbing spot-checks
nix eval .#nixosConfigurations.wsl.config.host.isWsl                  # true
nix eval .#nixosConfigurations.workstation.config.host.isWsl          # false
nix eval .#homeConfigurations.linux.config.host.isWsl                 # false
```

Warning gate: zero eval warnings (no `'system' has been renamed`, no HM
release mismatch) before declaring steps done.

Post-real-deploy (user, per host): shell tools present (tmux/nvim/yazi),
`win32yank.exe` reachable + clipboard round-trip, `wslview https://nixos.org`
opens Windows browser, yazi yank works (T1 regression test), no unit failures
(`systemctl --failed`).

## 8. Documentation Pass (same-change rule)

| Doc | Update |
|-----|--------|
| `decisions.md` | #55: nixos-wsl over HM-only WSL (T9 evidence); #56: minimal host-flags strategy (imports-for-exclusion); #57: headless hosts inline identity (D9). Mark TODO-stretch #222 superseded-by-plan. |
| `module-contracts.md` | Registry rows: `wsl`/`linux` hosts, `optionsHost` (both scopes); contract C27: `host.*` flags are per-class declarations, set in BOTH evaluations for nested hosts; clipboard/cmdLine branching notes. |
| `documentation/user/maintenance.md` | WSL + linux sections: deploy/update commands, rollback (`wsl` generations / `home-manager generations`), `wsl --shutdown` caveat, Windows-Terminal font note. |
| `README.md` | Host table: workstation, laptop, wsl (nixosConfigurations), linux (homeConfigurations); quick-start per target. |
| `AGENTS.md` | §4 example already shows wsl-workstation shape — align option names (`host.isWsl` not `custom.flags`) when touched next; §2 note `ubuntu.nix`→`linux.nix` rename. |
| `TODO.md` | New section per protocol; stretch #222 closed as superseded. |

## 9. Out of Scope

- macOS / nix-darwin (no hardware; stub remains).
- Server host flesh-out (separate future plan; will reuse `host.isServer`-style
  flag IF a real consumer emerges).
- Impermanence/persist-state for WSL or linux.
- Multi-username templating (hardcoded elichall everywhere, D5).
- blesh (T5 — dead in toolbox, not missed here).
- Distributable custom `.wsl` tarball pipeline (`tarballBuilder`) — possible
  follow-up once the official-tarball flow is proven tedious.
