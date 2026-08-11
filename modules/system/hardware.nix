# nixos.hardware — Generic system-wide hardware services (system scale).
#
# Template for leaning out modules/configuration.nix (nixos.main).
# Planned content (currently in nixos.main):
#   - hardware.bluetooth (enable, powerOnBoot, Source,Sink,Media,Socket)
#   - services.fstrim (SSD TRIM)
#   - services.fwupd (firmware updates)
#   - hardware.cpu.intel.updateMicrocode
#   - services.earlyoom (OOM protection)
#
# NOTE: machine-specific hardware (fileSystems, boot modules, microcode) stays
# in nixos.hardwareConfig (modules/system/hardware-t480.nix).
# NOT wired into any host until populated.
{ inputs, ... }: {
  flake.modules.nixos.hardware = { ... }: { };
}
