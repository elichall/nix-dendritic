# ==========================================================================
# FLATPAK — registry renderer (hand-installed apps; one module per app)
# ==========================================================================
# Reads `flatpak.apps` (modules/options/flatpakOpt.nix) and writes the files
# Flatseal would: ~/.local/share/flatpak/overrides/<app-id> (HM-owned, read-only
# symlinks — edit in the app's module, not Flatseal) and optional .desktop
# entries. mimeapps and Hyprland rules are rendered by their own modules from the
# same registry. Apps are installed by hand from flathub.
# Contract: modules/_assets/documentation/module-contracts.md; decisions.md #64/#65.
{ ... }: {
  flake.modules.homeManager.flatpak = { config, lib, ... }:
    let
      apps = config.flatpak.apps;
    in
    {
      xdg.dataFile =
        lib.mapAttrs' (
          id: app: lib.nameValuePair "flatpak/overrides/${id}" { text = app.overrides; }
        ) (lib.filterAttrs (_: a: a.overrides != "") apps)
        // lib.mapAttrs' (
          id: app: lib.nameValuePair "applications/${id}.desktop" { text = app.desktopEntry; }
        ) (lib.filterAttrs (_: a: a.desktopEntry != null) apps);
    };
}
