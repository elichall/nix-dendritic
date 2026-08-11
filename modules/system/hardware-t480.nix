# t480 machine-specific hardware: fileSystems, kernel modules, microcode.
# Imported by hosts via `self.modules.nixos.hardwareConfig`.
{ inputs, ... }: {
  flake.modules.nixos.hardwareConfig = { config, lib, ... }: {
    imports =
      [ "${inputs.nixpkgs}/nixos/modules/installer/scan/not-detected.nix"
      ];

    boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-intel" ];
    boot.extraModulePackages = [ ];

    fileSystems."/" =
      { device = "/dev/disk/by-uuid/b5e1073f-37db-410c-a47c-e350f6246637";
        fsType = "ext4";
      };

    fileSystems."/boot" =
      { device = "/dev/disk/by-uuid/21A2-ED34";
        fsType = "vfat";
        options = [ "fmask=0022" "dmask=0022" ];
      };

    swapDevices = [ ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
