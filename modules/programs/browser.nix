# ==========================================================================
# BROWSER ABSTRACTION
# ==========================================================================
# Sets config.browser.{appId,command,desktop} for Zen Browser (Firefox flatpak).
# Consumers: hyprland (keybind), mime (defaultApplications), otter (tokens).
{ ... }: {
  flake.modules.homeManager.browser = {
    config.browser = {
      appId = "org.mozilla.firefox";
      command = "flatpak run org.mozilla.firefox";
      desktop = "org.mozilla.firefox.desktop";
    };
  };
}
