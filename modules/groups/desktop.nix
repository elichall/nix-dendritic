# ==========================================================================
# DESKTOP GROUP — display/wallpaper preset
# ==========================================================================
# Aggregates display-aspect modules for GUI hosts. Individual keys remain
# importable. Wired via `self.modules.nixos.desktop` and
# `self.modules.homeManager.desktop`.
{ self, ... }: {
  flake.modules.nixos.desktop = {
    imports = [
      self.modules.nixos.display
      self.modules.nixos.hyprland
      self.modules.nixos.mime
    ];
  };

  flake.modules.homeManager.desktop = {
    imports = [
      self.modules.homeManager.hyprland
      self.modules.homeManager.ghostty
      self.modules.homeManager.tui
      self.modules.homeManager.zotero
      self.modules.homeManager.showoff
      self.modules.homeManager.awww
      self.modules.homeManager.waypaper
      self.modules.homeManager.wallpapers
      self.modules.homeManager.waybar
      self.modules.homeManager.theme
    ];
  };
}
