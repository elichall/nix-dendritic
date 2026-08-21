# ==========================================================================
# CLIPBOARD (wl-clipboard)
# ==========================================================================
# Cross-host core integration; future homeManager.clipboard may grow here. Registry
# map: modules/_assets/documentation/module-contracts.md (§1).
# ==========================================================================
{ inputs, ... }: {
  flake.modules.homeManager.clipboard = { pkgs, ... }: {
    home.packages = [ pkgs.wl-clipboard ];
  };
}
