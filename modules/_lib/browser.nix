# Shared Zen Browser identifiers (DRY source).
# Imported from feature modules via `import ../_lib/browser.nix`.
# Kept out of the import-tree because it defines no `flake.modules.*`.
{
  # Flatpak app ID used by org.gnome.Software / org.freedesktop.appstream
  appId = "app.zen_browser.zen";

  # Launcher command (flatpak wrapper)
  command = "flatpak run app.zen_browser.zen";

  # Desktop entry ID, as used by xdg.mime.defaultApplications and .desktop files
  desktop = "app.zen_browser.zen.desktop";
}
