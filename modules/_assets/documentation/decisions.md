# Development Decisions Log

Architecture, migration, and operational decisions made while building the
dendritic Nix configuration. This is the **why**; AGENTS.md records the rules,
TODO.md records the *what*, and the skills record the *how*. Cross-module
interface contracts live in `module-contracts.md`; system upkeep commands live
in `maintenance.md`.

Decision entries follow: **Decision → Context/Rationale → Where encoded.**

---

## Part 1 — Architecture foundation (AGENTS.md Rules)

### 1. Aspect-oriented module structure (AGENTS.md Rule 1)
**Decision:** Group modules by *feature aspect*, not target-system class. One
`.nix` file holds all scopes (nixos / homeManager / darwin) for one feature.
No `nixos/`-vs-`home-manager/`-vs-`darwin/` trees.
**Why:** A feature's system-scale and user-scale halves evolve together and
reference the same binaries and configs. Separating by target class fragments
a single concern across three trees and forces cross-tree imports on every
change. This is the core enabling rule for the universal-repo long-term goal.
**Where:** AGENTS.md §3 Rule 1; `modules/display/ghostty.nix`, `hyprland.nix`,
`programs/nvim.nix` (dual-scope modules); display-launcher features isolated
per scope (see #13).

### 2. Path agnosticism via import-tree (AGENTS.md Rule 2)
**Decision:** Every non-underscore `.nix` under `modules/` is auto-imported by
`import-tree`. No explicit relative imports between feature modules. Moving a
file must never break the build.
**Why:** Directory structure becomes pure organization, free to reorganize.
Cross-module sharing is handled by `_lib/` (see #15) and the 2-level registry
(see #6), not by relative `import ../foo.nix`.
**Where:** AGENTS.md §3 Rule 2; `flake.nix` (`inputs.import-tree ./modules`).

### 3. Strict scope separation (AGENTS.md Rule 3)
**Decision:** `flake.modules.nixos.*` = system-wide concerns only (kernel,
bootloader, hardware, systemd services, caches, users, system packages).
`flake.modules.homeManager.*` = user-level concerns only (dotfiles, aliases,
user units, tool config).
**Why:** A user-scale tool does not belong in the system profile and vice
versa; scope drives packaging (see #13) and prevents profile bloat.
**Where:** AGENTS.md §3 Rule 3; the module registry map in `module-contracts.md`.

### 4. Per-module dependency self-containment (AGENTS.md Rule 4)
**Decision:** Every module declares every package it consumes, even if another
module *configures* that tool. Duplicate declarations across modules are
explicitly allowed and encouraged. Presence (packages) and configuration are
independent concerns.
**Why:** Removing a module from a host must never break another module's
runtime. `environment.systemPackages`/`home.packages` merge by concatenation,
so repeats are deduplicated in the final profile — self-containment is free.
**Limits:** Applies to mergeable list options only. Non-list options set to
different values across modules produce "conflicting definitions" — feature
*configuration* is owned by exactly one module. Declare at one scope level
(user tooling → `home.packages`, system services → `environment.systemPackages`).
**Where:** AGENTS.md §3 Rule 4; visible in `modules/display/waybar.nix`,
`showoff.nix`, `otter-launcher/otter.nix` (see #24 for the otter exception).

### 5. Host + feature-flag adaptation pattern
**Decision:** Hosts are thin entry points that aggregate registry modules and
expose feature flags (`isWSL`, `isDesktop`, `isServer`) consumed by modules.
**Why:** One repo must configure any machine; flags let shared modules adapt
evaluation without host-specific branching.
**Status:** Only `workstation` is real today. Skeleton hosts (`wsl`, `ubuntu`,
`macos`, `server`) are defined but blocked on `specialArgs` → `extraSpecialArgs`
(Home Manager 26.05 renamed the argument — see flake-validator skill).
**Where:** AGENTS.md §4; `modules/hosts/workstation.nix`.

### 6. Registry is strictly 2-level → aspect groups as presets
**Decision:** The flake-parts registry is `class -> name -> module` (two
levels only; no nested namespaces). Aggregate presets ("groups") are regular
registry modules whose `imports` reference sibling entries.
**Why:** import-tree/flake-parts flatten nested dirs; namespacing groups
re-introduces the tree the architecture removes. Groups (base/desktop/toolbox)
give hosts a one-line inclusion while keeping every key individually
importable.
**Where:** `modules/groups/{base,desktop,toolbox}.nix`; `workstation.nix`
collapses to `main + hardwareConfig + base + desktop + toolbox + singles`.

---

## Part 2 — Composition & packaging decisions

### 7. No bare NixOS modules in `modules/` (hardwareConfig wrap)
**Decision:** Machine/NixOS-only config must be wrapped as a registry module
(e.g. `modules/system/hardware-t480.nix` →
`flake.modules.nixos.hardwareConfig`), referenced via
`self.modules.nixos.hardwareConfig`.
**Why:** import-tree recurses every non-underscore file into the flake-parts
evaluation; a raw NixOS module (`fileSystems`, `boot.*`, `modulesPath`
imports) recurses/breaks that eval. Verified empirically during t480 wiring.
**Where:** assets-lib skill; `modules/system/hardware-t480.nix`.

### 8. `nixos.main` lean-down + `system/` splits
**Decision:** `modules/configuration.nix` (`nixos.main`) is base identity only:
stateVersion, bootloader + zram, time/locale, users, nix-ld, fonts, base
systemPackages, flatpak, tmpfiles, nix.settings/gc. Feature scopes extracted
to `system/` splits: network, hardware, audio, security, battery, mime,
clipboard.
**Why:** A single 300-line main module defeats modularity; the splits are the
"base system" preset (`nixos.base`) a non-desktop host reuses unchanged.
**Where:** `modules/configuration.nix` header map; `modules/system/*.nix`.

### 9. `nix.settings` / `nix.gc` intentionally stay in `nixos.main`
**Decision:** GC schedule, auto-optimise-store, sandbox, and experimental
features are NOT moved to a split, despite a security split existing.
**Why:** User choice — these are cross-cutting, host-independent infrastructure
settings, not a "feature". Also the source of the maintenance writeup's GC
section (`maintenance.md` §5).
**Where:** `modules/configuration.nix:21` (comment), `nixos.main`.

### 10. Package placement: user tooling → `home.packages`
**Decision:** Every tool with zero system-level consumer moves to the user
scope: fastfetch (home-only), opencode, rclone binary, awww, waypaper,
hypridle/grimblast/brightnessctl/playerctl (into `homeManager.hyprland`),
wl-clipboard (into `homeManager.clipboard`).
**Why:** The user profile is the correct owner of user CLIs; the system
profile should not carry desktop/launcher tooling. Verified by per-module
consumer tracing during Phase 2.5.
**Notable exception:** `xdg-desktop-portal-gtk` MUST stay user-scale — the
daemon only finds it on the user profile (breaks the system otherwise;
user-confirmed).
**Where:** `modules/system/clipboard.nix`, `modules/programs/fastfetch.nix`,
`modules/home.nix` (portal-gtk), TODO Phase 2.5.

### 11. docker removed from systemPackages
**Decision:** docker dropped (unused on this host); the planned docker-service
split is therefore obsolete.
**Why:** User directive — no consumer; removal shrinks the closure.
**Where:** TODO Phase 2.5; absent from `nixos.main` systemPackages.

### 12. Package sourcing tiers (provisioning order)
**Decision:** Packages are sourced in strict tier order — (1) nixpkgs
`pkgs.<name>` → (2) pinned upstream flake input with
`inputs.nixpkgs.follows = "nixpkgs"` → (3) build from source as last resort.
Never skip tiers: a nixpkgs package is not fetched/built; a flake-having repo
is not tarball-fetched.
**Why:** `follows nixpkgs` builds upstream against OUR pinned nixpkgs (single
dependency closure). Tarball `fetchTarball` + local `buildRustPackage` for
wlctl/otter-launcher were eliminated in favor of Tier 2.
**Where:** package-provisioning skill; `flake.nix` (`wlctl`, `otter-launcher`);
`modules/display/tui.nix`, `otter-launcher/otter.nix`.

### 13. `pkgs.system` → `pkgs.stdenv.hostPlatform.system`
**Decision:** All flake-input package lookups use
`inputs.<name>.packages.${pkgs.stdenv.hostPlatform.system}`, never `pkgs.system`.
**Why:** Nixpkgs deprecated the bare `system` accessor; it emitted the
"`'system' has been renamed to/replaced by 'stdenv.hostPlatform.system'`"
evaluation warning on every rebuild.
**Where:** `modules/display/otter-launcher/otter.nix:35`, `waybar.nix:20`,
`tui.nix:18`.

### 14. Home Manager pinned to the matching release branch
**Decision:** `home-manager` input uses `release-26.05` to match the nixpkgs
26.05 pin.
**Why:** The un-branched input resolved to the 26.11 dev cycle, which builds
against nixpkgs 26.05 (via follows) and tripped Home Manager's release check
("versions mismatched"). Matching branches is the fix; suppressing the check
(`home.enableNixpkgsReleaseCheck = false`) is not.
**Where:** `flake.nix`; flake.lock.

---

## Part 3 — Runtime & state decisions

### 15. `_lib/` shared helpers instead of cross-module imports
**Decision:** Shared non-module values live in `modules/_lib/` (browser.nix,
theme.nix, interaction-watch.nix), consumed via explicit relative import from
the needing module. `_lib` never defines `flake.modules.*`, never imports a
feature module.
**Why:** Keeps Rule 2 (path agnosticism) while providing the DRY that was
missing (the legacy `nsp`/`gg` browser-focus idiom duplicated browser domain
knowledge that `_lib/browser.nix` now owns).
**Where:** assets-lib skill; `modules/_lib/*.nix`.

### 16. Theme zero-baseline: path indirection
**Decision:** No Nix config encodes a theme value. `~/.local/share/theme/
active.json` is the single source of truth; ghostty pulls the active theme via
a stable `config-file` path (`generated/ghostty/theme.conf`) that sync-ghostty
rewrites at runtime. `home.activation.initTheme` re-syncs after every switch.
**Why:** The deployed ghostty config never changes, so a home-manager switch
can never reset the theme; theme is inherently persistent state. This was the
"zero-baseline refactor" following the static-`theme =`-line approach.
**Where:** `modules/display/theme.nix`, `modules/display/ghostty.nix`,
`modules/_lib/theme.nix` (shared paths).

### 17. Theme state is NOT a `services.state` item
**Decision:** `active.json` deliberately not registered in the
`services.state.items` framework (see `../plans/deferred/state-implementation.md`), despite
being persistent state.
**Why:** That framework is systemd-based snapshot/restore for root services —
overkill for a user file that persists naturally; it belongs on the future
impermanence persist path instead.
**Where:** TODO Phase 3 (zero-baseline refactor); `modules/_assets/plans/
deferred/state-implementation.md`.

### 18. GTK palette-only contract
**Decision:** The generated GTK CSS (`~/.config/gtk-{3,4}.0/gtk.css`) is
palette-only — `@define-color` lines, NO element rules.
**Why:** It is user-priority CSS loaded by EVERY GTK3/GTK4 app. Element rules
leaked: an opaque `window` background killed ghostty transparency/blur; a
`label { color }` rule turned waybar's workspace numbers white; `.drag` themed
ripdrag's pill. Postmortem: `modules/_assets/documentation/ghostty-transparency.md`.
**Where:** `modules/display/theme.nix` header (trimmed; see
`module-contracts.md`), `documentation/ghostty-transparency.md`.

### 19. Shared interaction watcher unifies showoff + otter
**Decision:** One process-agnostic cursor watcher,
`modules/utils/interactionWatch.nix`, replaces otter's broken `dismiss-on-pointer.sh`
and showoff's inline watcher. Modelled on showoff's WORKING watcher.
**Why:** Two implementations of the same idea; otter's `pgrep -f` pattern
never matched (the real comm is bare `otter-launcher`), so dismiss never
fired. A single tested helper with `--on-move` callbacks removes the class of
bug.
**Where:** `modules/utils/interactionWatch.nix` (flake-parts module with
`flake.utils.interactionWatch` export); consumers showoff + otter via
`self.utils.interactionWatch pkgs`.

### 20. Dismiss = `pkill -x otter-launcher` (exact comm)
**Decision:** Launcher dismissal uses exact-comm `pkill -x otter-launcher`;
the bail check uses `--bail-comm otter-launcher` (exact `pgrep -x`).
**Why:** Verified live — the launcher's comm is `otter-launcher`; `pkill -x`
kills only the launcher, its window closes naturally, the persistent ghostty
server survives. `hyprctl dispatch closewindow` is broken under the Lua config
(`hl.dispatch` hook); regex matches over-match the ghostty server
(`--class=com.otter.launcher`) and the spawning client. See #19.
**Where:** `modules/display/otter-launcher/otter.nix` (otter-launch + bail).

### 21. Ghostty config ownership contract
**Decision:** `homeManager.ghostty` is the SOLE owner of
`xdg.configFile."ghostty/config"`. The theme module must not declare it.
**Why:** Two modules setting the same non-mergeable option = conflicting-
definition error. Ownership + runtime-only theming (see #16) is the interface.
**Where:** `modules/display/ghostty.nix` + `theme.nix` (now via
`module-contracts.md`).

### 22. Waybar/hyprland PATH strategy
**Decision:** In desktop configs, user-scope binaries are referenced by
absolute store path; system-scope binaries (nmcli, wpctl, hyprctl) stay
PATH-based; module-owned wrappers stay PATH-based until their focused passes
land.
**Why:** The graphical session does not reliably carry the Home Manager
profile on PATH; absolute paths guarantee the binary regardless of session
environment. Discovered when keybinds silently failed post-switch.
**Where:** `modules/display/waybar.nix`, `hyprland.nix` (headers → contracts).

### 23. `systemd.enable = false` for waybar/hyprland; awww→waypaper chain (reverted)
**Decision:** Home Manager's systemd integration is disabled for waybar and
hyprland — UWSM tracks their execution. Wallpaper restoration originally ran
via `waypaper-restore.service` (Requires `awww-daemon.service`), replacing a
duplicate `waypaper --restore` autostart line. **Reverted 2026-08-11:** under
UWSM `graphical-session.target` never activates, so both units were dead code
and wallpaper was never restored after rebuild. `awww-daemon` and
`waypaper --restore` now launch via `hl.exec_cmd` in the hyprland autostart
block (restore deferred 0.5s); the systemd units were removed.
**Why:** UWSM is the session manager of record; the unit chain proved inert
because its trigger target never fires in this session model. Launching from
`hyprland.start` guarantees the compositor is up and WAYLAND_DISPLAY is set.
**Where:** `modules/display/hyprland.nix`, `waypaper.nix`, `awww.nix`.

### 24. Rule 4 Hybrid — otter's module-owned CLI exception
**Decision:** Otter gets a narrow, documented exception: the module-owned CLIs
(`theme`, `otter-apps`) that live in sibling modules and cannot be cleanly
re-declared as `home.packages` are audited by `otter-diagnose` (18 checks)
plus a `home.activation` warning hook that never fails the build.
**Why:** Full Rule 4 compliance is impossible for wrappers another module
owns; auditing converts "assumed present" into "warned if missing" without
breaking rebuilds.
**Where:** this document #24; `modules/display/otter-launcher/otter.nix`
(otter-diagnose + activation hook).

### 25. `config.toml` token protocol (mkOtterConfig)
**Decision:** `config.toml` is a template with `@TOKEN@` placeholders;
`mkOtterConfig` substitutes them so menu variants (app/pow) are attrset
overrides. Tokens live in both files — adding one means editing both.
**Why:** Two near-identical configs (app vs power menu) were hand-maintained
in legacy; substitution collapses the duplication. Legacy collapsed 2
duplicate token pairs during the port.
**Where:** `modules/display/otter-launcher/otter.nix` (mkOtterConfig),
`config.toml`.

### 26. Waybar weather + otter-open PATH note
**Decision:** Until the focused otter pass lands, waybar's `otter-open`
on-click is PATH-based; weather exec uses absolute curl/sed. Fastfetch/btop
declared in showoff for the tmux panes (Rule 4).
**Where:** `modules/display/waybar.nix`; see `module-contracts.md` for the
module-owned wrapper status table.

---

## Part 4 — Process & validation decisions

### 27. Validation workflow (parse → registry → drvPath gates)
**Decision:** Before every commit: `nix-instantiate --parse` sweep over all
modules, registry eval (`nix eval .#modules --apply ...`), then
`toplevel.drvPath` + `home-manager activationPackage.drvPath` dry evals as the
exit gates.
**Why:** Full `nixos-rebuild switch` on every change is slow and risky; the
drvPath evals type-check the whole system + user config without building.
**Where:** flake-validator skill; TODO validation status sections.

### 28. Git dirty-tree gate
**Decision:** Files must be `git add`ed before evaluation/build — the flake
only sees tracked files. New `.nix`/asset files invisible to the build until
staged.
**Why:** Nix resolves path literals against the git tree; an untracked
`config.toml` or icon silently evaluates as "not found" (or worse, a stale
tracked copy is used). Hit during the otter port.
**Where:** flake-validator skill; package-provisioning skill (step 1 of
validation); `maintenance.md` §2.

### 29. Hash-granularity gate CLOSED
**Decision:** drvPath/package-order differences are NOT a validation signal
unless something is actually breaking. Only eval success + config equivalence
matter.
**Why:** Legitimate reorderings (input follows, module merge order) shift
store hashes without any behavioral change; chasing them produced noise.
**Where:** TODO Phase 2.5 (user directive 2026-08-10).

### 30. Legacy snapshot kept as reference
**Decision:** `/etc/nixos/{configuration,home,hardware-configuration}.nix` +
legacy modules copied to tracked `legacy/`; `/etc/nixos` left as the dormant
pre-switch config (gitignored symlink).
**Why:** Frozen source-of-truth reference for Phase 3 ports and debugging.
Note: `legacy/` carries the pre-fix gtk.css transparency bug — always port
from the LIVE `/etc/nixos` tree, not `legacy/` (see theme.nix provenance).
**Where:** TODO Phase 2.5; `legacy/`.

### 31. `_assets` must stay tracked; root `.gitignore` anchor
**Decision:** `modules/_assets/` (icons, wallpapers, images, docs) is tracked;
the root `.gitignore` rule is root-anchored (`/_assets/`) so `modules/_assets`
is included. Asset paths resolve from the consuming file's own directory.
**Why:** Pure flake evaluation requires tracked assets; un-anchoring the
ignore would silently exclude the icons/wallpapers the modules reference.
**Where:** assets-lib skill; flake-validator skill; `.gitignore`.

### 32. Shell-integration defaults explicitly off
**Decision:** `home.shell.*` integrations (fish/ion/nushell/zsh) explicitly
disabled in `homeManager.cmdLine`; bash is the only interactive shell.
**Why:** Home Manager 26.05 defaults every integration on; e.g. fzf enables
its nushell integration and trips an assertion (requires fzf ≥ 0.73.0).
**Where:** `modules/programs/cmdLine.nix`.

### 33. Frozen / do-not-touch items
- `homeManager.cmdLine` `bashrcExtra` hm-session-vars sourcing — user reported
  issues; do NOT touch without explicit go-ahead (TODO stretch).
- `services.state.items` bluetooth persistence — REACH, left as-is (TODO
  stretch; `../plans/deferred/state-implementation.md`).
- Ghostty window rules/classes in hyprland (incl. the dead `com.center.focus`
  rule) — deliberately kept as legacy (phase-3 decision, void).
- `dk`/`obs` config.toml menu stubs — left as-is (phase-3 decision).

### 34. Adaptive nvim plugin framework
**Decision:** Feature modules contribute nvim plugin specs, completion sources,
and LSP servers via generated Lua files that are activation-merged into the
nvim config directory. Base configs use `pcall(require, "lean.<feature>")`
to load features at runtime — missing features degrade silently.
**Why:** The base nvim config deploys as a store symlink via
`xdg.configFile."nvim"`. Feature modules can't add files alongside a store
symlink (HM can't write inside store paths). The activation hook resolves the
symlink, copies the directory, and layers feature files on top. This keeps
nvim light when features aren't imported — zero plugins, zero LSPs, zero cost.
**Where:** `modules/research/obsidian.nix` (activation hook + feature files),
`_assets/dotfiles/nvim/init.lua` (pcall pattern), `lsp.lua` (feature LSP
merge), `module-contracts.md` C21.

### 35. Obsidian.nvim legacy_commands + explicit keymaps
**Decision:** Set `legacy_commands = false` in obsidian.nvim opts and define
custom keymaps (`gl`, `[o`, `]o`) via lazy.nvim's `keys` spec. Picker forced
to `mini.pick` (auto-detect failed).
**Why:** obsidian.nvim v4 deprecated CamelCase commands (`:ObsidianFollowLink`)
in favor of `:Obsidian <cmd>` subcommands. Setting `legacy_commands = false`
silences deprecation warnings and ensures new API usage. `ui.enable = false`
does NOT control keymaps — `vim.g.obsidian_default_keymap` does (defaults to
true). Explicit `keys` entries ensure the custom keymaps work regardless of
obsidian.nvim's internal autocmd setup. Auto-detect for picker failed; forcing
`mini.pick` avoids falling back to the built-in native UI.
**Where:** `modules/research/obsidian.nix` lines 52-55, 58, 68.

### 36. Blink-cmp-bibtex trigger override
**Decision:** Use `provider.override.get_trigger_characters` to return
`{ "@" }` for the bibtex source, rather than relying on blink.cmp's default
trigger detection.
**Why:** The pandoc citation matcher (which detects `@citekey` syntax) does NOT
declare any trigger characters. Without the override, blink.cmp never invokes
the bibtex source on `@` keystrokes — it only triggers from the buffer source's
fallback. The override forces blink.cmp to activate the bibtex source when the
user types `@`.
**Where:** `modules/research/obsidian.nix` lines 113-117.

### 37. BibTeX auto-discovery via recursive glob
**Decision:** Replace hardcoded `global_files` list with a `discover_bib_files()`
Lua function that recursively globs `~/Documents/me/vault/**/*.bib` and
`~/Documents/test/**/*.bib` at load time.
**Why:** User has many `.bib` files across their research career (e.g.
`~/Documents/me/vault/class/26-summer/DBM/dbm_paper.bib`). Manual listing is
unsustainable and requires config edits whenever a new `.bib` file is created.
Recursive glob auto-discovers all bibliography files in vault directories.
**Where:** `modules/research/obsidian.nix` lines 29-43, 91.

### 38. Research group (dedicated preset)
**Decision:** Research-aspect modules aggregate into `homeManager.researchGroup`
(`groups/research.nix`) — separate from `toolbox` (core dev tools, no GUI)
and `desktop` (display/compositor). The group contains `research` (pandoc +
texlive), `obsidian` (nvim vault integration), and `zotero` (flatpak desktop
entry).
**Why:** Toolbox is deliberately core developer tools only (shell, git, tmux,
nvim base, yazi, opencode). Research tools are GUI-adjacent (pandoc produces
docx/pdf, Zotero is a GUI app) and carry nvim extension baggage (obsidian.nvim,
blink-cmp-bibtex). A dedicated group keeps concerns isolated and lets hosts
opt in to the full research stack with one import.
**Where:** `modules/groups/research.nix`, `workstation.nix`,
`module-contracts.md` C16.

### 39. Research aspect redundancy cleanup
**Decision:** Remove dead code, deduplicate configs, and add community-recommended
obsidian.nvim defaults. Specifically:
- Removed `researchLspLua` + generated `lsp.lua` — redundant with `lsp` table
  in `init.lua`; base `lsp.lua` reads from `lean.research.lsp` via pcall.
- Removed redundant `dependencies = { "saghen/blink.cmp" }` from bibtex spec.
- Removed redundant `default` list in blink.cmp deep-merge spec.
- Added `frontmatter = { enabled = false }` — prevents auto-formatting of YAML
  on save (community consensus from meow_d blog, froko gist).
- Added `checkbox = { create_new = false, order = { " ", "x" } }` — disables
  paragraph-to-checkbox on Enter; limits to 2 standard states.
- Added `booktabs` + `mdwtools` to texlive — required by pandoc's default
  xelatex template for table rules and table footnotes.
**Why:** The generated `lsp.lua` was identical to the `lsp` table already in
`init.lua`. `frontmatter` and `checkbox` are universally recommended by the
obsidian.nvim community. `booktabs`/`mdwtools` were discovered via nix-shell
testing as missing template dependencies.
**Note:** Attempted `default = function(list)` pattern (blink.cmp's recommended
way to extend sources) but it conflicts with obsidian.nvim's
`check_completion_availability` — that function iterates blink.cmp's config and
calls any functions it finds, passing nil. The `per_filetype` rewrite remains.
**Where:** `modules/research/obsidian.nix`, `modules/research/default.nix`,
`module-contracts.md` C21.

### 40. Vault root workspace + templates
**Decision:** Expand obsidian.nvim workspace from `research/` subfolder to full
vault root (`~/Documents/me/vault`). Add `templates.folder = ".templates"`
with `<leader>nt` keybinding for `:ObsidianTemplate`.
**Why:** Vault restructured with 3-layer indexing (folders → faceted tags →
wikilinks). MOCs, concept notes, class notes, and projects live outside
`research/`. Workspace must cover full vault for wikilink resolution.
Templates consolidated into vault-wide `.templates/` directory.
**Where:** `modules/research/obsidian.nix`.

### 41. BibTeX hierarchical walk
**Decision:** Replace recursive `**/*.bib` glob with a `global_files` function
that receives `bufnr` and walks up from the buffer directory to the vault root
(directory containing `.obsidian/`), collecting `*.bib` at each level. Each
buffer only sees `.bib` files in its directory chain up to the vault root.
**Why:** Static `global_files` list gave every buffer access to every `.bib`
file across all vaults. Per-buffer scoping prevents cross-vault pollution and
matches the user's mental model (a paper sees its own references plus parent
directories up to the vault root).
**How:** `global_files = discover_bib_files` (function reference, not call).
blink-cmp-bibtex's `scan.resolve_option` calls it via `pcall(value, bufnr)`
per completion round. `pcall` silently catches errors, so the function wraps
its own body in `pcall` for debuggability. Nix `''` string requires `''''`
escaping for Lua `''` literals.
**Where:** `modules/research/obsidian.nix`.

### 42. No Podman/Docker — stay Nix-native for container images
**Decision:** Do not enable Podman or Docker. Prefer native NixOS service modules
(`services.*`) for all services. If a third-party OCI image is ever required,
build it with `pkgs.dockerTools` (Nix derivation, no daemon) rather than pulling
from a registry at runtime.
**Why:** User has no Docker/Podman experience and the server architecture
(`server-architecture-decisions.md`) already settled on native `services.*`
modules for all planned services (Nextcloud, Adguard, WireGuard). Adding Podman
introduces a foreign ecosystem (image registries, Dockerfiles, volume management)
outside the Nix module system with no current use case. `pkgs.dockerTools` covers
the edge case of needing to produce or consume OCI images without adopting the
Docker/Podman runtime.
**Where:** `modules/programs/sandbox.nix`, `modules/_assets/plans/vm-sandbox-integration.md`.

### 43. Sandbox infrastructure as a program module
**Decision:** Create `modules/programs/sandbox.nix` (`nixos.sandbox`) to enable
virtualization infrastructure (libvirtd + KVM). No aspect group — hosts opt in
by importing `self.modules.nixos.sandbox` directly. Actual sandbox definitions
(vmVariant config, container declarations) stay per-project or per-host, not
baked into the system config.
**Why:** System-level enablement (libvirtd daemon, user groups, KVM access) requires
root and kernel config — it belongs in NixOS scope. But sandbox *definitions*
(the shape of each VM/container) are project-specific concerns that should travel
with the code, not pollute the host config. The module owns the platform; hosts
and projects own the instances.
**Where:** `modules/programs/sandbox.nix`, `modules/_assets/documentation/module-contracts.md`.

### 44. Noctalia Shell replaces hand-rolled display stack (stable)
**Decision:** Replace the hand-rolled waybar + theme + awww + waypaper stack
with Noctalia Shell on the stable workstation host. Noctalia provides: theme
engine, top bar, dock, wallpaper management, clipboard history, and
notification daemon — all via a single `programs.noctalia.enable` HM module.
**Why:** The hand-rolled stack (waybar config/style, theme.nix profile sync,
awww notification daemon, waypaper wallpaper restore) carried significant
maintenance burden and fragile autostart chains (decision #23). Noctalia is a
purpose-built Hyprland companion with native theme generation, built-in battery
widget (reads UPower D-Bus), and documented TOML config. Validated with
`noctalia config validate` (zero warnings). Otter-launcher kept (user preference);
showoff ported to terminal abstraction.
**Where:** `modules/display/desktop/noctalia.nix`, `groups/desktop.nix`,
`module-contracts.md` C23.

### 45. Foot replaces ghostty (stable stack)
**Decision:** Use foot terminal on the stable workstation host; ghostty remains
on the experimental laptop host.
**Why:** Noctalia's theme engine generates foot INI theme files natively. Foot
is a mature, lightweight Wayland-native terminal with native HM integration
(`programs.foot.enable`). Ghostty remains on the experimental stack (laptop)
where the full hand-rolled theme engine is still active. The terminal is fully
abstracted via `_lib/terminal.nix` — consumer modules never hardcode the terminal
name.
**Where:** `modules/display/desktop/foot.nix`, `hosts/workstation.nix`,
`module-contracts.md` C22.

### 46. 3-host split: laptop (experimental), workstation (Noctalia stable), server (headless)
**Decision:** Split into three distinct host configurations:
- **workstation** (`custom.terminal = "foot"`): Noctalia shell, foot terminal,
  lean stable stack. Production desktop.
- **laptop** (`custom.terminal = "ghostty"`): Full experimental stack (waybar,
  ghostty, theme engine, awww, waypaper). Development/experimental desktop.
- **server** (empty stub): Headless, no display stack. Future work.
**Why:** The experimental stack (waybar, ghostty, theme engine) carries ongoing
maintenance burden and instability. The stable stack (Noctalia, foot) is
purpose-built for Hyprland and requires minimal config. Separating hosts lets
the production workstation stay stable while the laptop serves as a sandbox for
new features. Both hosts share core infrastructure (hyprland, tui, otter,
showoff) via the terminal abstraction.
**Where:** `modules/hosts/{workstation,laptop,server}.nix`,
`module-contracts.md` host wiring section.

### 47. Terminal abstraction via `_lib/terminal.nix`
**Decision:** Create a terminal abstraction library (`_lib/terminal.nix`) that
provides terminal-agnostic exec, execClass, and package helpers. Hosts select
their terminal via a NixOS option (`custom.terminal`), and all consumer modules
(hyprland, waybar, showoff, otter, tui) use the abstraction instead of
hardcoding terminal names.
**Why:** Multiple modules needed to launch commands in terminal windows
(hyprland keybinds, waybar clicks, showoff dashboard, otter launcher). Without
abstraction, every module would need a `terminalName` parameter and terminal-
specific branching (foot `--app-id` vs ghostty `--class`). The abstraction
centralizes this: one library owns the exec logic, consumers just call
`terminal.exec` or `terminal.execClass`. Adding a new terminal requires editing
only `_lib/terminal.nix` and the host's `custom.terminal` value.
**Where:** `modules/_lib/terminal.nix`, `module-contracts.md` C22.

### 48. UPower for Noctalia battery widget
**Decision:** Enable `services.upower.enable = true` in `system/battery.nix`
to provide battery status via D-Bus for the Noctalia battery widget.
**Why:** Noctalia's battery widget and Control Center battery settings read
from the UPower D-Bus service (`org.freedesktop.UPower`). Without UPower
enabled, both are empty. UPower does NOT conflict with TLP: TLP manages power
policies (CPU governor, charge thresholds, PCIe ASPM); UPower provides
read-only battery status. Both can coexist — TLP is the policy engine, UPower
is the status reporter.
**Where:** `modules/system/battery.nix`, `module-contracts.md` C27.

### 49. `--class` → `--app-id` migration for foot
**Decision:** Replace all hardcoded `--class` flags with `terminal.execClass`
which branches: foot uses `--app-id`, ghostty uses `--class`. This affects
otter-launcher, showoff, and any other module spawning classified terminal
windows.
**Why:** Ghostty's `--class` flag is not recognized by foot. The otter-launcher
`otter-launch` script, showoff spawn/kill logic, and all other terminal-spawning
code silently failed with foot because `--class` is a no-op unknown flag.
The `execClass` function in `_lib/terminal.nix` resolves this by using the
correct flag per terminal. Showoff's class names also changed from `com.waybar.tui`
to `showoff.dash`/`showoff.sec` (dots, not dots-as-separators) for cross-terminal
compatibility.
**Where:** `modules/_lib/terminal.nix` (execClass), `modules/display/otter-launcher/otter.nix`,
`modules/display/experimental/showoff.nix`, `module-contracts.md` C5.

### 50. Showoff ported to terminal abstraction
**Decision:** Port showoff.nix to use `_lib/terminal.nix` for terminal exec
and class flags, removing all hardcoded ghostty references.
**Why:** Showoff spawns terminal windows for its dashboard and secondary views.
Without the terminal abstraction, it would need its own `terminalName` parameter
and terminal-specific branching. The port gives it the same `terminal.exec`,
`terminal.term`, and `CLASS_FLAG` (foot: `--app-id`, ghostty: `--class`) that
other modules use. pgrep/pkill patterns updated for foot's `--app-id` syntax.
tmux config updated to remove ghostty-specific `terminal-overrides` line.
**Where:** `modules/display/experimental/showoff.nix`, `module-contracts.md` C18.

### 51. TUI apps inherit terminal colors — no templates needed
**Decision:** TUI apps (nvim, btop, starship, opencode, tmux) do NOT need
Noctalia template plugins or community templates. They inherit the full
16-color palette from the active terminal emulator (foot) via standard
terminal color escape sequences.
**Why:** Noctalia's template engine generates config files for GUI apps that
read file-based themes (GTK, Qt, VSCode, Discord, etc.). TUI apps read
`terminal.color0`–`terminal.color15` directly from the terminal's palette.
Our foot terminal passes the full Catppuccin 16-color palette to all child
processes. Adding neovim/btop/starship/opencode templates would be redundant.
**Where:** `modules/_assets/documentation/user/noctalia-guide.md` §4 ("Which
apps need templates vs. which inherit terminal colors").

### 52. Terminal/dev theming integration: Approach A contract + noctalia-theme-sync
**Decision:** All terminal and dev tool theming follows "Approach A": Noctalia
(or theme engine) writes generated color files; program modules source them
agnostically without knowing who wrote them. A single `noctalia-theme-sync`
script fans out palette changes to all dev tools on every `colors_changed` hook.
**Why:** Clean module isolation — noctalia.nix owns the sync logic, program
modules own their config. Same file, different sources possible (noctalia vs
experimental theme.nix). The sync script parses the foot theme once and pushes
colors to: tmux (write `colors.tmux`), foot (OSC escape sequences), nvim
(remote-expr to clear cache + re-apply colorscheme), and opencode (SIGUSR2 to
force palette re-detection).
**Key finding:** SIGWINCH does NOT trigger palette re-detection in opencode —
it only handles terminal resize. SIGUSR2 is the correct signal for forcing
palette refresh. Verified by source code analysis of opencode's signal handlers.
**Where:** `modules/display/desktop/noctalia.nix` (noctalia-theme-sync script),
`module-contracts.md` C24-C26, `decisions.md` #52.

### 53. Options module pattern — auto-wiring defaults (Option A)
**Decision:** Eliminate `modules/_lib/` and all feature-module config setting.
Options files declare `options.*` with defaults that auto-resolve. Hosts set
config overrides only when divergent from defaults. Feature modules create
derivations and add to `home.packages` but NEVER set config values.
**Why:** Three categories of config values have different ownership needs:
- **Host identity** (`terminal.name`, `browser.name`): host owns
- **Derived computations** (`terminal.term`, `browser.command`): computed lazily
  from identity — nobody should set these manually
- **Custom derivations** (`utils.notifySend`): created by feature modules — hosts
  shouldn't redefine these
Option A solves all three cleanly: options files compute derived values lazily
from identity choices, and reference flake outputs for custom derivations. Hosts
are clean (2-3 lines of identity choices). No intermediate config-setting modules.
**Pattern:**
1. `modules/options/<name>Opt.nix` — declares `options.*` with `mkDefault`
   values that auto-resolve. Suffix `Opt` enables mini.pick file searching.
2. Feature modules create derivations, add to `home.packages`, export via
   flake outputs. Do NOT set config values.
3. Hosts set config overrides (identity choices). Most config resolved by defaults.
4. `modules/groups/options.nix` — bundles all `options/*Opt.nix` files.
5. No merged modules. No intermediate config-setting modules.
**Key design points:**
- Derived values use lazy `config.*` references: `term.default = "${pkgs.${config.terminal.name}}/bin/${config.terminal.name}"`
- Custom derivation defaults reference flake outputs: `default = self.utils.notifySend`
- Any host can override any value: `config.terminal.name = "ghostty"` cascades to all derived values
**Supersedes:** #53 (previous options pattern) and #47 (merged terminal pattern).
**Where:** `modules/options/{browser,terminal,theme,utils}Opt.nix`,
`modules/groups/options.nix`, `modules/utils/{notifySend,interactionWatch}.nix`,
`modules/system/mime.nix` (NixOS + HM scopes).

### 54. `lib.getExe` / `lib.getExe'` replaces `${pkgs.<name>}/bin/<name>`
**Decision:** Replace all `${pkgs.<name>}/bin/<name>` patterns with
`lib.getExe pkgs.<name>` (uses `meta.mainProgram`) or `lib.getExe' pkgs.<name> "binary"`
(for packages where mainProgram differs from pname, e.g. `coreutils`, `gnused`,
`jolt-tui`). Wrapped packages (`writeShellApplication`) use `lib.getExeFromWrappers`.
**Why:** `lib.getExe` ensures the correct output is chosen (packages can split
`bin` into a separate output). It reduces boilerplate — the path is derived from
the package's `meta.mainProgram` rather than hardcoded. For packages without
`meta.mainProgram` (e.g. `coreutils`), `lib.getExe'` with an explicit binary
name is required. This is a mechanical refactor with no behavioral change.
**Where:** All `.nix` files under `modules/` — 38 instances replaced across
hyprland, theme, ghostty, waybar, showoff, cmdLine, rclone, initProject,
otter, tui, notifySend, interactionWatch.

### 55. mimeDefaults merged into mime.nix — single file, dual scope
**Decision:** Folded `programs/mimeDefaults.nix` into `system/mime.nix`,
exporting both scopes from one aspect (`flake.modules.nixos.mime` = custom-mime
package; `flake.modules.homeManager.mimeDefaults` =
`xdg.mimeApps.defaultApplications`). Deleted `programs/browser.nix`
(declarations moved into `options/browserOpt.nix`).
**Why:** The NixOS-side custom-mime package and the HM-side associations are
two halves of one concern; keeping them in separate files forced cross-scope
coordination for no isolation benefit. Dual-scope export follows the
aspect-oriented rule (#1).
**Where:** `modules/system/mime.nix`, `modules/options/browserOpt.nix`,
contract C4.

### 56. Host option scaffold — possibility-space options with shared let-in defaults
**Decision:** `modules/options/hostOpt.nix` declares a `host.*` option tree in
BOTH scopes (sibling exports `nixos.optionsHost` + `homeManager.optionsHost`)
covering what any host *can be*: `isNixos`, `isWsl`, `displayProtocol`,
`shell`, `identity.{username,email,gitUsername,gitEmail}`. Defaults encode the
user's standard practice so template hosts (clone repo onto a new device →
make a host file → build) need zero overrides. Options may exist ahead of
consumers — this is deliberate scaffolding, each description names its
consumer.
**Why:** The near-term goal is skeleton/template hosts for wsl/linux/etc.
Encapsulating "what a host can even be" as typed options with standard-practice
defaults makes new-host creation an override exercise instead of a config
authoring exercise.
**Key sub-decisions:**
- **Cross-scope default sharing via file-level let**: nixos and HM are separate
  module-system evals; an HM default can never read nixos-scope config
  (standalone-HM hosts have no nixos eval at all). Shared literal defaults
  (`stdPractice`) live in one `let` consumed by both declarations. Semantic
  inheritance (`gitUsername ← username`) uses same-scope `config.host.identity.*`.
- **No per-host bridges**: rejected mirroring nixos values into nested HM via
  `mkDefault` blocks in host files — cascade machinery is deferred until a real
  nixos-side override need appears; hosts stay thin.
- **isNixos is tautological in nixos scope** (a `nixosSystem` IS NixOS) but
  meaningful in HM scope: standalone-HM hosts set false to enable foreign-distro
  behavior (`targets.genericLinux`). Kept symmetric for scaffold clarity.
- **First consumer wired practically before expansion**: `homeManager.git` now
  reads `config.host.identity.gitUsername/gitEmail`; further branching
  (clipboard/cmdLine on `isWsl`/`displayProtocol`/`shell`) deferred until the
  other hosts are defined.
**Gotchas hit:** sibling-export requirement (nested `flake.modules.*` inside a
module body breaks the inner class's eval); untracked file invisible to flake
eval until `git add`; `--raw` cannot print boolean eval results.
**Where:** `modules/options/hostOpt.nix`, `modules/groups/options.nix`
(both classes), `modules/programs/git.nix`, contract C28.

---

## Appendix — decision source index

| # | Decision | AGENTS.md | TODO.md | Skill | Doc |
|---|---|---|---|---|---|
| 1 | Aspect modules | Rule 1 | Phase 1 | domain-classifier | — |
| 2 | Path agnosticism | Rule 2 | Bootstrap | assets-lib | — |
| 3 | Scope separation | Rule 3 | Phase 1/2 | domain-classifier | — |
| 4 | Rule 4 self-containment | Rule 4 | Phase 2.5 | — | this doc #24 |
| 5 | Host flags | §4 | stretch hosts | — | — |
| 6 | 2-level registry + groups | — | Phase 2.5 groups | — | module-contracts |
| 7 | hardwareConfig wrap | — | Phase 2.5 | assets-lib, flake-validator | — |
| 8 | main lean-down | — | Phase 2.5 | — | module-contracts |
| 9 | nix.settings/gc in main | — | Phase 2.5 | — | maintenance §5 |
| 10 | user-scope placement | — | Phase 2.5 | — | module-contracts |
| 11 | docker removal | — | Phase 2.5 | — | — |
| 12 | provisioning tiers | — | Phase 2.5 wlctl | package-provisioning | — |
| 13 | stdenv.hostPlatform | — | (2026-08-11) | — | — |
| 14 | HM release pin | — | (2026-08-11) | — | maintenance §3 |
| 15 | _lib helpers | Rule 2 | Phase 2.5 | assets-lib | — |
| 16 | theme path indirection | — | Phase 3 zero-baseline | — | module-contracts |
| 17 | theme not services.state | — | Phase 3 | — | this doc #17 |
| 18 | GTK palette-only | — | Phase 3 GTK contract | — | ghostty-transparency |
| 19 | interaction-watch | — | otter Phase 1 | — | this doc #19 |
| 20 | pkill -x dismiss | — | otter Phase 1/2 | — | this doc #20 |
| 21 | ghostty ownership | — | Phase 2.5 | — | module-contracts |
| 22 | PATH strategy | Rule 4 | Phase 3 bulk | — | module-contracts |
| 23 | UWSM tracking | — | Phase 3 bulk | — | module-contracts |
| 24 | Rule 4 Hybrid | Rule 4 | otter Phase 2 | — | this doc #24 |
| 25 | config.toml tokens | — | otter port | — | this doc #25 |
| 26 | weather/otter-open PATH | Rule 4 | otter Phase 3 | — | module-contracts |
| 27 | validation gates | — | validation sections | flake-validator | — |
| 28 | git dirty-tree gate | — | Bootstrap | flake-validator | maintenance §2 |
| 29 | hash gate closed | — | Phase 2.5 | — | — |
| 30 | legacy snapshot | — | Phase 2.5 | — | — |
| 31 | _assets tracking | — | Phase 2 | assets-lib | — |
| 32 | shell integrations off | — | Bootstrap | flake-validator | — |
| 33 | frozen items | — | stretch/Phase 3 | — | this doc #33 |
| 34 | adaptive nvim framework | — | research workflow | — | module-contracts C21 |
| 35 | obsidian.nvim legacy_commands + keymaps | — | research workflow | — | research.md |
| 36 | blink-cmp-bibtex trigger override | — | research workflow | — | research.md |
| 37 | BibTeX auto-discovery glob | — | research workflow | — | research.md |
| 38 | research group | — | research workflow | — | module-contracts C16 |
| 39 | research aspect redundancy cleanup | — | research workflow | — | research.md, module-contracts C21 |
| 40 | vault root workspace + templates | — | research workflow | — | research.md |
| 41 | BibTeX hierarchical walk | — | research workflow | — | research.md |
| 42 | no Podman/Docker | — | sandbox | — | sandbox.nix, vm-sandbox-integration.md |
| 43 | sandbox infrastructure | — | sandbox | — | sandbox.nix, module-contracts |
| 44 | Noctalia Shell replaces hand-rolled stack | — | Noctalia migration | — | module-contracts C23 |
| 45 | Foot replaces ghostty (stable) | — | Noctalia migration | — | module-contracts C22 |
| 46 | 3-host split | — | Noctalia migration | — | module-contracts host wiring |
| 47 | Terminal abstraction via `config.terminal.*` (merged pattern → SUPERSEDED) | Rule 2 | _lib elimination | — | module-contracts C22 |
| 48 | UPower for battery status | — | Noctalia migration | — | module-contracts C27 |
| 49 | `--class` → `--app-id` migration (foot) | — | Noctalia migration | — | module-contracts C5 |
| 50 | Showoff ported to terminal abstraction | — | Noctalia migration | — | module-contracts C18 |
| 51 | TUI apps inherit terminal colors, no templates needed | — | Noctalia migration | — | noctalia-guide.md §4 |
| 52 | Terminal/dev theming: Approach A + noctalia-theme-sync | — | Noctalia migration | — | module-contracts C24-C26 |
| 53 | Options module pattern — auto-wiring defaults (Option A, supersedes original) | Rule 2 | _lib elimination | — | module-contracts C14 |
| 54 | `lib.getExe` / `lib.getExe'` replaces `${pkgs.<name>}/bin/<name>` | Rule 2 | _lib elimination | — | module-contracts C22 |
| 55 | `mimeDefaults.nix` merged into `mime.nix` (single file, dual scope) | Rule 1 | Option A cleanup | — | module-contracts C4, C16 |
| 56 | Host option scaffold — dual-scope `host.*`, shared let-in defaults | §4 | wsl-linux-hosts plan | options-architecture | module-contracts C28 |
