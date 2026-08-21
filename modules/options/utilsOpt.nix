# Utility script option declarations — bridge between flake outputs and HM config.
# WHY THIS EXISTS: notifySend and interactionWatch are created by modules/utils/*.nix
# as HM modules (they depend on config.programs.noctalia.enable). Flake outputs
# CAN'T reference HM config values — they're evaluated at flake scope, not module
# scope. These options let the module system wire the derivations to consumers
# (otter, showoff) via config.utils.* without leaking implementation details.
{ ... }: {
  flake.modules.homeManager.optionsUtils = { lib, ... }: {
    options.utils = {
      notifySend = lib.mkOption {
        type = lib.types.package;
      };
      interactionWatch = lib.mkOption {
        type = lib.types.package;
      };
    };
  };
}
