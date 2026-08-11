# ==========================================================================
# OPENCODE
# ==========================================================================
# User-scale (Home Manager): AI CLI on the user profile. No system-level
# consumer, so no nixos.* aspect.
{ inputs, ... }: {
  flake.modules.homeManager.opencode = { pkgs, ... }: {
    home.packages = [ pkgs.opencode ];
  };
}
