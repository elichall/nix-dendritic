# ==========================================================================
# TOOLBOX GROUP — developer toolchain preset
# ==========================================================================
# Aggregates user-scale developer/shell tools. Individual keys remain
# importable. Wired via `self.modules.homeManager.toolbox`.
{ self, ... }: {
  flake.modules.homeManager.toolbox = {
    imports = [
      self.modules.homeManager.cmdLine
      self.modules.homeManager.git
      self.modules.homeManager.tmux
      self.modules.homeManager.nvim
      self.modules.homeManager.yazi
    ];
  };
}
