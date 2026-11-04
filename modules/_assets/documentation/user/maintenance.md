# System Maintenance — Dendritic Flake vs Static `/etc/nixos`

How day-to-day NixOS maintenance changes now that the system is built from the
`nix-dendritic` flake (`~/.nix`) instead of the static
`/etc/nixos/configuration.nix` + channels setup. This is the operational
companion to AGENTS.md; keep it updated as the repo evolves.

---

## 1. Where the config lives now

- **Repo:** `~/.nix` — a user-owned git repository. No more
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
sudo nixos-rebuild switch --flake ~/.nix#workstation
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
# in ~/.nix, as your user (NOT sudo)

nix flake update                 # bump all inputs
# ...or bump just one:
nix flake lock --update-input nixpkgs

git add flake.lock
git commit -m "chore: bump nixpkgs input"   # commit the lock, then switch
sudo nixos-rebuild switch --flake ~/.nix#workstation
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

Frozen as one module per machine: `modules/system/hardware-t480.nix`
(registry key `nixos.t480-hardwareConfig`) and `modules/system/hardware-fw13p.nix`
(`nixos.fw13p-hardwareConfig`). These replaced `/etc/nixos/hardware-configuration.nix`.
Each machine needs its own unique key — a shared name breaks every host that
still imports the old one.

- **When hardware changes** (new disk layout, kernel modules, initrd needs),
  regenerate the reference and port the new bits:
  ```bash
  sudo nixos-generate-config
  # diff /etc/nixos/hardware-configuration.nix against modules/system/hardware-<machine>.nix
  ```
- It must stay wrapped in `flake.modules.nixos.<machine>-hardwareConfig` — bare NixOS
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
  flake = "~/.nix";
};
```

Caveats: it rebuilds whatever commit/state the repo is at (dirty trees build
dirty), and a misconfigured source can silently fall back to `/etc/nixos`.
Manual `nix flake update` + explicit switch is currently the deliberate choice.

---

## 9. Command cheat sheet

```bash
# Rebuild & activate
sudo nixos-rebuild switch --flake ~/.nix#workstation

# Stage for next boot only (no switch now) — servers
sudo nixos-rebuild boot --flake ~/.nix#workstation

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
```

---

## 10. New host checklist

Work through this when adding a machine (written after bringing up the
Framework 13 `fw13p`). `[N]` = Nix config, `[S]` = state Nix does not manage.

### Identity & wiring
- [ ] [N] New `modules/hosts/<name>.nix`; set `host.hostName` (hard eval error
      if unset — by design) and `system.stateVersion`.
- [ ] [N] Unique hardware module key (`nixos.<machine>-hardwareConfig`) from a
      fresh `sudo nixos-generate-config`: `fileSystems` UUIDs, swap, `kvm-intel`
      / `kvm-amd`, initrd modules.
- [ ] [N] `host.trustedSshKeys` on the new host, and the new host's pubkey
      (`~/.ssh/id_ed25519.pub`) added to every other host's list.
- [ ] [N] Search for stale references after any rename:
      `grep -rn "<old-registry-key>" modules/`.
- [ ] [N] Every host evaluates warning-free (the gate):
      ```bash
      for h in $(nix eval .#nixosConfigurations --apply builtins.attrNames --json | jq -r '.[]'); do
        nix eval --option abort-on-warn true .#nixosConfigurations.$h.config.system.build.toplevel.drvPath
      done
      ```
      Use `final.stdenv.hostPlatform.system` in overlays, never `final.system`.

### Hardware & firmware
- [ ] GPU userspace, not just the kernel driver: `nix shell nixpkgs#libva-utils -c vainfo`
      and `nix shell nixpkgs#vulkan-tools -c vulkaninfo --summary`. No VA-API
      driver = no hardware video decode (Intel: `intel-media-driver`, `vpl-gpu-rt`).
- [ ] Firmware: `fwupdmgr get-updates`. BIOS/system-firmware updates need AC
      power and an explicit accept for the *System Firmware* item.
- [ ] Kernel complaints: `journalctl -k -b -p warning` (ACPI `_CPC`, `ucsi_acpi`
      and a Wi-Fi firmware "falling back to older version" line are usually benign).
- [ ] Radios/sensors/peripherals: `nmcli dev`, `bluetoothctl list`, `wpctl status`,
      `ls /dev/video* /dev/accel*`, `fwupdmgr get-devices` (fingerprint reader).
- [ ] Decide on optional services (default off): `fprintd`, `thermald`,
      `hardware.bolt` (Thunderbolt/USB4 docks).
- [ ] `systemctl --failed` and `systemctl --user --failed` are empty.

### Power & battery
- [ ] Battery name: `ls /sys/class/power_supply/` (`BAT0` vs `BAT1`). Remove
      thresholds for batteries that don't exist.
- [ ] TLP thresholds only work if sysfs exposes
      `/sys/class/power_supply/BAT*/charge_control_*_threshold`. If absent (the
      fw13p case), set the limit in BIOS and drop the TLP threshold lines.
- [ ] Governor / EPP / platform profile actually applied while on battery:
      `cat /sys/devices/system/cpu/cpu0/cpufreq/{scaling_driver,scaling_governor,energy_performance_preference}`
      and `/sys/firmware/acpi/platform_profile{,_choices}`.
- [ ] Only one power daemon: `power-profiles-daemon` off when TLP is on.

### Display & session
- [ ] `host.display.scale` set for the panel (applies to the internal panel
      *and* the catch-all external-monitor rule). Resolutions should divide
      evenly by the scale (3840×2160 / 1.5 ✓).
- [ ] Internal panel connector name (`eDP-1`) matches the rules in
      `modules/display/hyprland.nix`; externals are port-independent (catch-all
      rule + hotplug hook): swap ports once and confirm with
      `hyprctl monitors` / `hyprctl workspaces`.
- [ ] XDG user dirs exist (`~/.config/user-dirs.dirs`, from
      `homeManager.xdgUserDirs`) — otherwise flatpak `xdg-download` mounts
      nothing and downloads vanish with the sandbox. Test:
      `flatpak run --command=ls org.mozilla.firefox ~/Downloads`.
- [ ] Portal routing: attribute names under `xdg.portal.config` must be
      lowercase (`hyprland`). `journalctl --user -u xdg-desktop-portal` must NOT
      say "via the deprecated UseIn key". Test the file dialog from Firefox.

### State Nix does not manage
- [ ] rclone: `rclone config` with the remote named exactly `boxdrive`, then
      `systemctl --user start rclone-box` (the unit asserts `rclone.conf` exists
      at login only).
- [ ] Git push auth: HTTPS remote prompts every time — switch to SSH
      (`git remote set-url origin git@github.com:…`, key registered on GitHub)
      or enable the `gh` credential helper.
- [ ] Tailscale login; Google Authenticator enrolment if `host.require2fa`.
- [ ] Flatpak apps are installed imperatively and are NOT in the flake
      (Firefox, Zotero, Flatseal, …): reinstall and re-apply permissions.
- [ ] First `nvim` launch compiles treesitter parsers (needs `gcc`, provisioned
      by `homeManager.nvim`); after a fix, `rm -rf ~/.cache/nvim/tree-sitter-*`.
- [ ] BIOS settings that Linux cannot see or set (battery charge limit, Secure Boot).

### Close-out
- [ ] Update `TODO.md` and the relevant `module-contracts.md` entry for any new
      option; commit with a clean tree and an up-to-date `flake.lock`.

---

## Maintenance ritual (condensed)

1. Edit modules; `git add` new files so the build sees them.
2. Commit (clean tree + committed `flake.lock` = reproducible switch).
3. `sudo nixos-rebuild switch --flake ~/.nix#workstation`.
4. Log in and spot-check the session.
5. Weekly: `nix flake update && git add flake.lock && git commit &&` switch.

---

## Noctalia Shell customization

Noctalia Shell v5 manages the top bar, dock, launcher, control center,
wallpaper, clipboard, and notifications on the stable workstation. Full
customization guide (bar widgets, plugins, theming, keybindings, Nix syntax):

→ `modules/_assets/documentation/user/noctalia-guide.md`

Quick reference for common tasks:

```bash
# View current settings
noctalia msg state all | jq .settings

# List available plugins
noctalia msg plugins list

# Enable a plugin
noctalia msg plugins enable noctalia/screen_recorder

# Restart Noctalia after config change
pkill noctalia-shell  # auto-restarts from hyprland autostart
```
