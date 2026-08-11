# nixos.audio — Audio stack (system scale).
#
# Template for leaning out modules/configuration.nix (nixos.main).
# Planned content (currently in nixos.main):
#   - security.rtkit.enable
#   - services.pipewire (alsa, alsa.support32Bit, pulse)
#
# NOT wired into any host until populated.
{ inputs, ... }: {
  flake.modules.nixos.audio = { ... }: { };
}
