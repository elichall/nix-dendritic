# ==========================================================================
# XDG USER DIRECTORIES (~/.config/user-dirs.dirs)
# ==========================================================================
# Flatpak resolves its `xdg-download` (etc.) filesystem permissions from the
# host's user-dirs.dirs. Without that file nothing is bind-mounted, so the
# Firefox flatpak saw no ~/Downloads and downloads vanished with the sandbox.
{ ... }: {
  flake.modules.homeManager.xdgUserDirs = { config, lib, ... }: {
    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      download = lib.mkDefault "${config.home.homeDirectory}/Downloads";
      pictures = lib.mkDefault "${config.home.homeDirectory}/Pictures";
      # Unused standard dirs: null so HM neither declares nor creates them.
      desktop = lib.mkDefault null;
      documents = lib.mkDefault "${config.home.homeDirectory}/Documents";
      music = lib.mkDefault null;
      publicShare = lib.mkDefault null;
      templates = lib.mkDefault null;
      videos = lib.mkDefault null;
    };
  };
}
