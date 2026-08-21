# hybrid-notify derivation — consumed by otter via config.utils.notifySend
{ self, ... }: {
  flake.modules.homeManager.optionsNotifySend = { lib, ... }: {
    options.utils.notifySend = lib.mkOption {
      type = lib.types.package;
    };
  };
}
