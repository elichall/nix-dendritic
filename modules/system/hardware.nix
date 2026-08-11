# nixos.hardware — Generic system-wide hardware services (system scale).
#
# Leaned out of modules/configuration.nix (nixos.main).
# Machine-specific hardware (fileSystems, boot modules) stays in
# nixos.hardwareConfig (modules/system/hardware-t480.nix).
# Wired into workstation.nix via `self.modules.nixos.hardware`.
{ inputs, ... }: {
  flake.modules.nixos.hardware = { ... }: {
    # ======================================================================
    # BLUETOOTH
    # ======================================================================
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };

    # ======================================================================
    # MAINTENANCE
    # ======================================================================
    # Solid State Drive TRIM
    # Maintains NVMe flash cell degradation and write speeds
    services.fstrim.enable = true;
    # Firmware Update Daemon
    # Allows updating BIOS, UEFI, and peripheral firmware directly via `fwupdmgr`
    services.fwupd.enable = true;
    # Intel CPU Microcode
    # Ensures the kernel loads the latest security and stability patches for the CPU
    hardware.cpu.intel.updateMicrocode = true;
    # Out-Of-Memory (OOM) Protection
    # Prevents hard system lockups during heavy RAM compilation workloads by killing
    # memory-hogging processes before the kernel freezes
    services.earlyoom.enable = true;
  };
}
