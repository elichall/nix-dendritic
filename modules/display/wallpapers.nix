# ==========================================================================
# WALLPAPERS (theme profiles + waypaper library)
# ==========================================================================
# User-scale (Home Manager): provisions the tracked wallpaper set from
# modules/_assets/wallpapers into ~/Pictures/Wallpapers. The Phase 3 theme
# module references these exact paths in its profiles, and waypaper --restore
# reads the same directory. Assets are tracked in modules/_assets so the
# flake evaluates purely (import-tree ignores underscore-prefixed paths).
# The file list is single-sourced in ../_lib/wallpapers.nix (shared with
# homeManager.theme, which asserts its profiles against it).
{ inputs, ... }: {
  flake.modules.homeManager.wallpapers = { lib, config, ... }: let
    wallpaperFiles = (import ../_lib/wallpapers.nix).all;
  in {
    home.file = builtins.listToAttrs (
      map (file: {
        name = "Pictures/Wallpapers/${file}";
        value.source = ../_assets/wallpapers/${file};
      }) wallpaperFiles
    );
  };
}
