# System Maintenance — Dendritic Flake vs Static `/etc/nixos`

How day-to-day NixOS maintenance changes now that the system is built from the
`nix-dendritic` flake (`~/Projects/nix-dendritic`) instead of the static
`/etc/nixos/configuration.nix` + channels setup. This is the operational
companion to AGENTS.md; keep it updated as the repo evolves.

---

## 1. Where the config lives now

- **Repo:** `~/Projects/nix-dendritic` — a user-owned git repository. No more
  `sudo`-ing around root-owned `/etc/nixos`.
- **Legacy references that are now inert:**
  - `/etc/nixos` — still holds the old static config. `nixos-rebuild` **defaults
    to `/etc/nixos/flake.nix`** (which does not exist here), so a bare
    `sudo nixos-rebuild switch` fails safely instead of silently rebuilding
    legacy. It is archive-only; can be deleted when you no longer want it.
  - `nixos -> /etc/nixos` symlink at the repo root — legacy pointer, also inert.
  - `legacy/` — frozen snapshot of the old config (gitignored), reference only.

**Why a home-dir git repo is the recommended practice** (NixOS wiki, NixOS
discourse consensus, migration guides): `/etc/nixos` is root-owned, which means
every file edit fights permissions, `nix flake update` has trouble writing
`flake.lock`, and `nix-shell` remaps `/etc` to a temporary dir that breaks
symlinks pointing back into `/etc/nixos`. Keeping the flake in `$HOME` as a git
repo avoids all three and makes the whole system reproducible from git history.

### The rebuild command (always with `--flake`)

```bash
sudo nixos-rebuild switch --flake ~/Projects/nix-dendritic#workstation
```

`workstation` is the host key (`flake.nixosConfigurations.workstation`).
Always pass it — forgetting `--flake` (or the `#host`) makes nixos-rebuild fall
back to `/etc/nixos` (fails here, but don't rely on that).

---

## 2. The git dirty-tree gotcha (critical)

Flakes build from the **git working tree**, not the raw filesystem:

- **Untracked new files are invisible to the build.** A `.nix` file (or a data
  file like `config.toml` consumed via `builtins.readFile`) that has not been
  `git add`-ed simply does not exist as far as `nixos-rebuild` is concerned.
  This bit us during the otter-launcher port: the build silently used the old
  file until `git add` was run.
- **Tracked-but-uncommitted edits build**, but tag the flake as *dirty*, which
  means the resulting generation is not exactly reproducible from a commit.

**Practice:** commit (or at least `git add -A`) before every `nixos-rebuild
switch`. A clean tree + committed `flake.lock` = a switch you can rebuild
byte-for-byte from git history.

---

## 3. Updating packages — `flake.lock`, not channels

The old flow (`sudo nix-channel --update && nixos-rebuild switch`) is gone.
Flakes pin every input by revision in `flake.lock`; nothing updates unless you
tell it to.

### Inputs of this flake (`flake.nix`)

| Input | Source | Tracks |
|---|---|---|
| `nixpkgs` | `github:NixOS/nixpkgs/nixos-26.05` | driver |
| `home-manager` | `github:nix-community/home-manager` | `follows nixpkgs` |
| `wlctl` | `github:aashish-thapa/wlctl/v0.1.9` | `follows nixpkgs` |
| `otter-launcher` | `github:kuokuo123/otter-launcher/v0.7.6` | `follows nixpkgs` |
| `flake-parts` / `import-tree` | pinned | static |

Because `home-manager`, `wlctl`, and `otter-launcher` all `follows nixpkgs`,
bumping nixpkgs cascades the nixpkgs revision through all of them in one step.

### Update workflow (weekly is the recommended cadence)

```bash
# in ~/Projects/nix-dendritic, as your user (NOT sudo)

nix flake update                 # bump all inputs
# ...or bump just one:
nix flake lock --update-input nixpkgs

git add flake.lock
git commit -m "chore: bump nixpkgs input"   # commit the lock, then switch
sudo nixos-rebuild switch --flake ~/Projects/nix-dendritic#workstation
```

- `nix flake update` == recreate the lock; `nix flake lock --update-input X`
  == bump only `X` (transitive `follows` inputs follow along).
- **Never run `nix flake update` as root** — it edits `flake.lock` in a git
  repo and can break file permissions.
- `nixos-rebuild --upgrade` is now meaningless (it only updates the old root
  channel). Don't use it.
- The built system identifies itself by the nixpkgs revision in the lock, e.g.
  `t480-nixos-26.05.20260809.fcb8fcd`. Keep `system.stateVersion = "26.05"` in
  `modules/configuration.nix` unchanged unless you are deliberately doing a
  release-version migration.

---

## 4. Generations & rollback (unchanged from static)

- **Boot menu:** systemd-boot keeps previous generations; pick an older one to
  boot it. `boot.loader.systemd-boot.configurationLimit = 3` (in
  `modules/configuration.nix`) caps the retained boot entries, same as before.
- **Rollback to previous generation:**
  ```bash
  sudo nixos-rebuild --rollback switch
  ```
  or boot the previous generation from the bootloader menu (survives reboot).
- **Home-manager rides inside the system generation** (wired via the
  `home-manager` NixOS module), so rolling back the system rolls back the user
  config too. To inspect: `nixos-rebuild list-generations`.

---

## 5. Garbage collection

Already automated in `modules/configuration.nix`:

```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 14d";
};
```

plus `nix.settings.auto-optimise-store = true` (hardlink dedupe).

- **Manual sweep:** `sudo nix-collect-garbage -d` — also deletes old
  generations, so you lose rollback to them. Only do this once you know the
  current generation is good.
- The store grows fastest with a `nixos-rebuild switch` right after a `nix
  flake update`; the weekly automatic GC handles that.

---

## 6. Hardware configuration

Frozen as a module: `modules/system/hardware-t480.nix` (registry key
`nixos.hardwareConfig`). This replaced `/etc/nixos/hardware-configuration.nix`.

- **When hardware changes** (new disk layout, kernel modules, initrd needs),
  regenerate the reference and port the new bits:
  ```bash
  sudo nixos-generate-config
  # diff /etc/nixos/hardware-configuration.nix against modules/system/hardware-t480.nix
  ```
- It must stay wrapped in `flake.modules.nixos.hardwareConfig` — bare NixOS
  modules cannot live under `modules/` because import-tree recurses every
  `.nix` into the flake-parts evaluation.
- `fileSystems` must match reality or the switch fails its assertion — expected.

---

## 7. Mutable state

- **Theme state:** `~/.local/share/theme/` (active theme, generated palettes)
  lives outside the store and survives every switch/reboot by design — that is
  how the theme survives rebuilds. Never move it into the store-managed tree.
- **Dotfiles:** HM-managed files under `~/.config` are symlinks into the store,
  rewritten on each switch. Anything the legacy config created but the new one
  does not manage stays as a plain (possibly stale) file — clean those up when
  you find them.
- **User systemd units** (`rclone-box`) are per-user, activate with
  `default.target`, and are re-created on switch. The wallpaper daemon
  (`awww-daemon`) and restore (`waypaper --restore`) are NOT systemd units —
  they launch from the hyprland autostart block on `hyprland.start` (see
  decision #23 in `decisions.md`).

---

## 8. Optional: automatic updates (not enabled)

`system.autoUpgrade` is **not** configured. If you want it later:

```nix
system.autoUpgrade = {
  enable = true;
  flake = "~/Projects/nix-dendritic";
};
```

Caveats: it rebuilds whatever commit/state the repo is at (dirty trees build
dirty), and a misconfigured source can silently fall back to `/etc/nixos`.
Manual `nix flake update` + explicit switch is currently the deliberate choice.

---

## 9. Command cheat sheet

```bash
# Rebuild & activate
sudo nixos-rebuild switch --flake ~/Projects/nix-dendritic#workstation

# Stage for next boot only (no switch now) — servers
sudo nixos-rebuild boot --flake ~/Projects/nix-dendritic#workstation

# Dry-run build without switching
nix build .#nixosConfigurations.workstation.config.system.build.toplevel

# Update everything / one input
nix flake update
nix flake lock --update-input nixpkgs

# Inspect
nix flake metadata
nixos-rebuild list-generations
nix store diff-closures /run/current-system /nix/store/<path-to-new-toplevel>

# Rollback
sudo nixos-rebuild --rollback switch

# Garbage collection (manual; automatic weekly GC already configured)
sudo nix-collect-garbage -d

# Post-switch verification (run in the graphical session)
./post-switch-smoke-test.sh
```

---

## Maintenance ritual (condensed)

1. Edit modules; `git add` new files so the build sees them.
2. Commit (clean tree + committed `flake.lock` = reproducible switch).
3. `sudo nixos-rebuild switch --flake ~/Projects/nix-dendritic#workstation`.
4. Log in and run `./post-switch-smoke-test.sh`.
5. Weekly: `nix flake update && git add flake.lock && git commit &&` switch.
