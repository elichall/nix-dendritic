# ==========================================================================
# ONLYOFFICE (flatpak org.onlyoffice.desktopeditors — installed by hand)
# ==========================================================================
# Registry entry (modules/options/flatpakOpt.nix). Quirks learned the hard way:
# - Dialogs (file chooser etc.) are separate Xwayland windows, class
#   "DesktopEditors" (main window: "ONLYOFFICE"), that request position 0,0 and
#   open in the top-left corner -> centered by a Hyprland rule.
# - Default `titlebar=custom` draws a transparent shadow margin that eats tile
#   space -> manual `titlebar=native` (see notes; app-owned file).
{ ... }: {
  flake.modules.homeManager.flatpakOnlyoffice = { ... }: {
    flatpak.apps."org.onlyoffice.desktopeditors" = {
      mimeTypes = [
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        "application/msword"
        "application/vnd.ms-word.document.macroEnabled.12"
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        "application/vnd.ms-excel"
        "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        "application/vnd.ms-powerpoint"
        # csv / ODF intentionally unclaimed (csv stays with the nvim default)
      ];

      windowRules = [
        {
          name = "onlyoffice_dialogs";
          match.class = "^DesktopEditors$";
          center = true;
        }
      ];

      notes = [
        "Set `titlebar=native` in ~/.var/app/org.onlyoffice.desktopeditors/config/onlyoffice/DesktopEditors.conf with the app CLOSED (it rewrites the file on exit). Removes the transparent custom-frame border. Repeat on a fresh install / new host."
      ];
    };
  };
}
