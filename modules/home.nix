# ==========================================================================
# HOME MANAGER MAIN MODULE
# ==========================================================================
# User-level base ported from the legacy /etc/nixos/home.nix inline content.
# - Shell stack (bash/starship/zoxide/fzf/direnv/ble.sh) -> homeManager.cmdLine
# - Editor session vars                              -> homeManager.nvim
# - LSPs                                             -> homeManager.nvim
# - Terminal emulator                                -> homeManager.ghostty
# - TUI app launcher (entries/wrappers/icons/binaries) -> homeManager.tui
# - File manager env + config                        -> homeManager.yazi
# - Zotero                                           -> homeManager.zotero
# - Showoff dashboard deps                           -> homeManager.showoff
# - otter-launcher deps (qalc/chafa) live here until
#   the homeManager.otter-launcher port (Phase 3) absorbs them.
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

    # XDG portal + MIME defaults (defaultApplications live in nixos.mime)
    xdg.enable = true;

    # Packages managed by home-manager not by root
    home.packages = with pkgs; [
      # gtk.portal must live in the user profile so the daemon finds it
      xdg-desktop-portal-gtk

      # otter-launcher dependencies (migrate to homeManager.otter-launcher in Phase 3)
      libqalculate
      chafa
    ];
  };
}
