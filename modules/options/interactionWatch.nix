# interaction-watch derivation — consumed by otter and showoff via config.utils.interactionWatch
{ self, ... }: {
  flake.modules.homeManager.optionsInteractionWatch = { lib, ... }: {
    options.utils.interactionWatch = lib.mkOption {
      type = lib.types.package;
    };
  };
}
