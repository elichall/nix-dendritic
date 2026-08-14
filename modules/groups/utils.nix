# ==========================================================================
# PERSONAL UTILITY SCRIPTS
# ==========================================================================
{ self, ... }: {
  flake.modules.homeManager.utils = {
    imports = [
      self.modules.homeManager.initProject
    ];
  };
}
