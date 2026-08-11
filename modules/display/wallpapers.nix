# ==========================================================================
# WALLPAPERS (theme profiles + waypaper library)
# ==========================================================================
# User-scale (Home Manager): provisions the tracked wallpaper set from
# modules/_assets/wallpapers into ~/Pictures/Wallpapers. The Phase 3 theme
# module references these exact paths in its profiles, and waypaper --restore
# reads the same directory. Assets are tracked in modules/_assets so the
# flake evaluates purely (import-tree ignores underscore-prefixed paths).
{ inputs, ... }: {
  flake.modules.homeManager.wallpapers = { lib, config, ... }: let
    wallpaperFiles = [
      # Theme profile wallpapers (12)
      "beach.jpg"
      "boat-mountain.jpg"
      "lake-mountain.jpg"
      "mountain-birds.png"
      "mountain-green.jpg"
      "outer-wilds.jpg"
      "rain-lake.jpg"
      "snow-peak.jpg"
      "space-purple.jpg"
      "sunset-elk.jpg"
      "sunset-hills.jpg"
      "zelda-botw.jpg"
      # Waypaper library extras (5)
      "crimson-sunset.jpg"
      "mystic-valley.jpg"
      "red-mountain.png"
      "snow-mountain.jpg"
      "sunrise-elk.jpg"
    ];
  in {
    home.file = builtins.listToAttrs (
      map (file: {
        name = "Pictures/Wallpapers/${file}";
        value.source = ../_assets/wallpapers/${file};
      }) wallpaperFiles
    );
  };
}
