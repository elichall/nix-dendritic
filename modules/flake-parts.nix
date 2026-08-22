{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.modules
    # Declares flake.homeConfigurations / flake.homeModules as mergeable
    # outputs — required for standalone-HM hosts (linux, wsl).
    inputs.home-manager.flakeModules.home-manager
  ];
}
