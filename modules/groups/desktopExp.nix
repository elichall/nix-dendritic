# ==========================================================================
# CUSTOM EXPERIMENTAL DESKTOP GROUP
# ==========================================================================
# Aggregates display-aspect modules for GUI hosts. Individual keys remain
# importable. Wired via `self.modules.nixos.desktopExp` and
# `self.modules.homeManager.desktopExp`.
{ self, ... }: {
  flake.modules.nixos.desktopExp = {
    imports = [
      self.modules.nixos.display
      self.modules.nixos.hyprland
      self.modules.nixos.mime
    ];
  };

  flake.modules.homeManager.desktopExp = {
    imports = [
      self.modules.homeManager.hyprland
      self.modules.homeManager.ghostty
      self.modules.homeManager.tui
      self.modules.homeManager.otterLauncher
      self.modules.homeManager.showoff
      self.modules.homeManager.awww
      self.modules.homeManager.waypaper
      self.modules.homeManager.waybar
      self.modules.homeManager.theme
      self.modules.homeManager.browser
      self.modules.homeManager.mimeDefaults
      self.modules.homeManager.themePaths
      self.modules.homeManager.terminal
    ];
  };
}
