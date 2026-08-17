# Shared Zen Browser identifiers (DRY source).
# Imported from feature modules via `import ../_lib/browser.nix`.
# Kept out of the import-tree because it defines no `flake.modules.*`.
{
  # Flatpak app ID used by org.gnome.Software / org.freedesktop.appstream
  appId = "org.mozilla.firefox";

  # Launcher command (flatpak wrapper)
  command = "flatpak run org.mozilla.firefox";

  # Desktop entry ID, as used by xdg.mime.defaultApplications and .desktop files
  desktop = "org.mozilla.firefox.desktop";
}
