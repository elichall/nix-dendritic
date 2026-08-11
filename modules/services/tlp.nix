# ==========================================================================
# TLP POWER MANAGEMENT
# ==========================================================================
# Ported from the legacy /etc/nixos/configuration.nix. Laptop battery-charge
# thresholds and CPU power policies.
{ inputs, ... }: {
  flake.modules.nixos.tlp = { pkgs, ... }: {
    services.power-profiles-daemon.enable = false;
    services.tlp = {
      enable = true;
      settings = {
        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;

        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "low-power";

        PCIE_ASPM_ON_AC = "default";
        PCIE_ASPM_ON_BAT = "powersupersave";
      };
    };
  };
}
