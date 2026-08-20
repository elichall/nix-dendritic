# ==========================================================================
# STABLE WORKSTATION DESKTOP WITH NOCTALIA SHELL
# ==========================================================================
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
      self.modules.homeManager.foot
      self.modules.homeManager.tui
      self.modules.homeManager.noctalia
      self.modules.homeManager.otterLauncher
      self.modules.homeManager.showoff
    ];
  };
}
