# Shared tracked wallpaper set (DRY source).
# Imported from feature modules via `import ../_lib/wallpapers.nix`.
# Kept out of the import-tree because it defines no `flake.modules.*`.
#
# Single authoritative list of every wallpaper tracked in
# modules/_assets/wallpapers. homeManager.wallpapers provisions these into
# ~/Pictures/Wallpapers; homeManager.theme references the `theme` subset in
# its profiles. Keep this list and modules/_assets/wallpapers in sync.
rec {
  # Theme-profile wallpapers (referenced by homeManager.theme THEME_PROFILES)
  theme = [
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
  ];

  # Waypaper library extras (not tied to a theme profile)
  library = [
    "crimson-sunset.jpg"
    "mystic-valley.jpg"
    "red-mountain.png"
    "snow-mountain.jpg"
    "sunrise-elk.jpg"
  ];

  # Full provisioned set
  all = theme ++ library;
}
