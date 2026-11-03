# ==========================================================================
# GIT
# ==========================================================================
# Commit identity from the host scaffold (config.host.identity.*); requires
# homeManager.options imported before this aspect.
{ inputs, ... }: {
  flake.modules.homeManager.git = { config, ... }: {
    programs.git = {
      enable = true;
      settings.user.name = config.host.identity.gitUsername;
      settings.user.email = config.host.identity.gitEmail;

      delta = {
        enable = true;
        options = {
          theme = "Dracula";
          navigate = true;
          light = false;
          side-by-side = true;
          line-numbers = true;
        };
      };

      extraConfig = {
        merge = {
          conflictStyle = "zdiff3";
        };
      };
    };
  };

}
