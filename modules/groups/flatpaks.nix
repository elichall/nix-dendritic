# ==========================================================================
# FLATPAK GROUP — hand-installed flatpak apps preset
# ==========================================================================
# Aggregates one module per flatpak app
# (modules/programs/flatpak/). The renderer (`flatpak`) lives in the options group, so
# individual keys stay importable (a host may take just `flatpakOnlyoffice`).
# Importing an app's module is what pulls its quirks into mimeapps, Hyprland and
# flatpak overrides. Wired via `self.modules.homeManager.flatpakGroup`.
{ self, ... }: {
  flake.modules.homeManager.flatpakGroup = {
    imports = [
      self.modules.homeManager.flatpakOnlyoffice
      self.modules.homeManager.flatpakParaview
      self.modules.homeManager.flatpakFreecad
      self.modules.homeManager.flatpakSteam
      self.modules.homeManager.flatpakZotero
    ];
  };
}
