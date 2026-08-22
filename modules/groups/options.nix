# ==========================================================================
# CROSS-MODULE OPTIONS DECLARATIONS
# ==========================================================================
# Option declarations (decision #53). Feature modules set config values;
# hosts override identity choices. Suffix `Opt` in filenames for mini.pick.
{ self, ... }: {
  flake.modules.nixos.options = {
    imports = [
      self.modules.nixos.optionsHost
    ];
  };

  flake.modules.homeManager.options = {
    imports = [
      self.modules.homeManager.terminal
      self.modules.homeManager.optionsTheme
      self.modules.homeManager.browser
      self.modules.homeManager.optionsUtils
      self.modules.homeManager.optionsHost
    ];
  };
}
