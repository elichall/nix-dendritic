# ==========================================================================
# CROSS-MODULE OPTIONS DECLARATIONS
# ==========================================================================
# Pure option declarations — no config values. Feature modules in later phases set values.
{ self, ... }: {
  flake.modules.homeManager.options = {
    imports = [
      self.modules.homeManager.optionsInteractionWatch
      self.modules.homeManager.optionsNotifySend
      self.modules.homeManager.optionsTerminal
      self.modules.homeManager.optionsBrowser
    ];
  };
}
