# ==========================================================================
# HOME MANAGER MAIN MODULE — user-level base. Feature bits live in their own
# aspect modules (registry map: modules/_assets/documentation/module-contracts.md).
# ==========================================================================
{ inputs, ... }: {
  flake.modules.homeManager.main = { config, pkgs, ... }: {
    home.stateVersion = "26.05";

    home.username = "elichall";
    home.homeDirectory = "/home/elichall";

    # ==========================================================================
    # GLOBAL ENVIRONMENT CONFIGURATION
    # ==========================================================================
    # EDITOR/VISUAL/SUDO_EDITOR live in homeManager.nvim.
    # FILEMANAGER/TERM_FILE_CHOOSER live in homeManager.yazi.
    home.sessionVariables = {
      XCOMPOSECACHE = "${config.home.homeDirectory}/.cache/compose-cache";
    };

    home.pointerCursor = {
      enable = true;
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
      dotIcons.enable = false; # disable legacy ~/.icons mirror; XDG ~/.local/share/icons suffices
    };

    # XDG portal + MIME defaults (defaultApplications live in homeManager.mimeDefaults)
    xdg.enable = true;

    # Packages managed by home-manager not by root
    home.packages = with pkgs; [
      # gtk.portal must live in the user profile so the daemon finds it
      xdg-desktop-portal-gtk
    ];
  };
}
