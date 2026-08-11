# ==========================================================================
# CLIPBOARD (wl-clipboard)
# ==========================================================================
# Clipboard integration (wl-copy / wl-paste) is a core component shared by
# various system hosts (desktop, WSL, etc.), so it gets its own module.
# User-scale (Home Manager): the Wayland clipboard tooling. A system-scale
# (`nixos.clipboard`) aspect may grow here for hosts that need clipboard
# tooling at the system level.
{ inputs, ... }: {
  flake.modules.homeManager.clipboard = { pkgs, ... }: {
    home.packages = [ pkgs.wl-clipboard ];
  };
}
