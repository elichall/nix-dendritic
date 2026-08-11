# nixos.audio — Audio stack (system scale).
#
# Leaned out of modules/configuration.nix (nixos.main).
# Wired into workstation.nix via `self.modules.nixos.audio`.
{ inputs, ... }: {
  flake.modules.nixos.audio = { ... }: {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
