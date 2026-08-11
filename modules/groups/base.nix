# ==========================================================================
# BASE GROUP — system-level base services preset
# ==========================================================================
# Aggregates the system/ split modules for a base (non-desktop-specific)
# host. Individual keys remain importable. Wired via
# `self.modules.nixos.base`.
#
# NOTE: registry is strictly 2-level (class -> name -> module); groups are
# aggregate keys whose `imports` reference sibling registry entries.
{ self, ... }: {
  flake.modules.nixos.base = {
    imports = [
      self.modules.nixos.battery
      self.modules.nixos.network
      self.modules.nixos.hardware
      self.modules.nixos.audio
      self.modules.nixos.security
    ];
  };
}
