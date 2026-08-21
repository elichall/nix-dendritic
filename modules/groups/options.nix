# ==========================================================================
# CROSS-MODULE OPTIONS DECLARATIONS
# ==========================================================================
# Pure option declarations — no config values. Feature modules in later phases set values.
# Note: terminal is NOT here — it follows the merged pattern (declares + sets in one file).
{ self, ... }: {
  flake.modules.homeManager.options = {
    imports = [
      self.modules.homeManager.optionsInteractionWatch
      self.modules.homeManager.optionsNotifySend
      self.modules.homeManager.optionsBrowser
    ];
  };
}
