# Skill: Flatpak App Registry

## Purpose
How hand-installed flatpak apps (installed with `flatpak install flathub <id>`)
get their settings into the config without hard references in shared modules.
Contract: `module-contracts.md` C30; rationale: `decisions.md` #65.

## Layout
- `modules/options/flatpakOpt.nix` — declares `flatpak.apps.<app-id>`.
- `modules/programs/flatpak/flatpak.nix` — renderer (override files, .desktop).
- `modules/programs/flatpak/<app>.nix` — ONE module per app (`homeManager.flatpak<App>`).
- `modules/groups/flatpaks.nix` — `flatpakGroup`, the attach-in-one-line list.
- Consumers (never name an app): `system/mime.nix`, `display/hyprland.nix`.

## Adding an app
1. New file `modules/programs/flatpak/<app>.nix` exporting
   `flake.modules.homeManager.flatpak<App> = { ... }: { flatpak.apps."<id>" = { ... }; };`
2. Fill only the fields it needs: `overrides` (flatpak override ini), `mimeTypes`,
   `windowRules` (Nix attrsets → `hl.window_rule`, e.g.
   `{ name = "x"; match.class = "^X$"; center = true; }`), `desktopEntry`, `notes`.
3. Add it to `flatpakGroup` (or import it on a single host). Do NOT also import it
   anywhere else — `lines` options concatenate and would double the text.
4. Build, then diff the generated `mimeapps.list`, `hypr/hyprland.lua`, and
   `flatpak/overrides/<id>` to confirm only the intended lines changed.
5. Header comment: what the quirk was and why (short); long prose goes in `decisions.md`.

## Debugging a misbehaving flatpak (workflow that produced this registry)
- `hyprctl clients -j` — class, `xwayland`, `at`/`size` (a dialog at `[0,0]` means the
  app asked for 0,0 → `center` rule; match the DIALOG's class, it can differ from
  the main window's, e.g. OnlyOffice `DesktopEditors` vs `ONLYOFFICE`).
- `flatpak info --show-metadata <id>` — sockets/env the app ships with (X11-only,
  pinned `QT_QPA_PLATFORM`).
- Blurry text under fractional scale = Xwayland; force native Wayland via an
  override, or scale the app itself (`STEAM_FORCE_DESKTOPUI_SCALING`).
- App-owned config files (`~/.var/app/<id>/...`) are NOT Nix-managed: record the
  manual step in the app's `notes`.

## Gotchas
- Flatpak override files are HM read-only symlinks; edit in the app module, not Flatseal.
- `toLua` renders keys as `["name"] = ...` — valid for Hyprland's Lua API (verified).
- New `.nix` files must be git-tracked (`git add -N`) before `import-tree` sees them.
