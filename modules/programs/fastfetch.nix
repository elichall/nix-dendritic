# ==========================================================================
# FASTFETCH
# ==========================================================================
# User-scale (Home Manager) only: binary exposure for showoff-layout / waybar
# user scripts + chafa block-image NixOS logo. fastfetch links libchafa
# statically, so no runtime chafa dep (Rule 4 n/a).
# Plan: modules/_assets/plans/fastfetch-customization.md
{ inputs, ... }: {

  flake.modules.homeManager.fastfetch = { config, ... }: {
    programs.fastfetch = {
      enable = true;
      settings = {
        logo = {
          source = "${config.home.homeDirectory}/.nix/modules/_assets/nixos-image.png";
          type = "chafa";
          width = 40;
          height = 0;
          padding = {
            top = 1;
            right = 1;
          };
          chafa = {
            symbols = "block+semi";
            canvas = "full";
          };
        };
      };
    };
  };
}
