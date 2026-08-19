# nixos.sandbox — Virtualization & containerization infrastructure (system scale).
#
# Enables the platform for sandboxing: KVM acceleration (already in
# hardware-t480.nix kernelModules), libvirtd for VM management, and Podman
# for OCI containers. Actual sandbox definitions (vmVariant config,
# container declarations) are per-project or per-host — this module only
# turns on the plumbing.
# Wired into hosts via `self.modules.nixos.sandbox`.
{ inputs, ... }: {
  flake.modules.nixos.sandbox = { pkgs, lib, ... }: {
    # ======================================================================
    # KVM ACCELERATION
    # ======================================================================
    # /dev/kvm is already accessible via boot.kernelModules = ["kvm-intel"]
    # in hardware-t480.nix. KVM is the hardware boundary that makes VMs
    # viable — without it, QEMU falls back to TG emulation (10-50x slower).

    # ======================================================================
    # LIBVIRT (VM MANAGEMENT DAEMON)
    # ======================================================================
    # Provides virsh CLI, storage pools, virtual networks, and the libvirt
    # management API over QEMU. Needed for persistent VMs, snapshots, and
    # bridged networking. Ephemeral vmVariant VMs don't require this.
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        swtpm.enable = true; # TPM 2.0 emulation (required by some guests)
      };
    };

    # ======================================================================
    # USER PERMISSIONS
    # ======================================================================
    # libvirtd group membership lets the user manage VMs without sudo.
    users.users.elichall.extraGroups = [ "libvirtd" ];
  };
}
