# ==========================================================================
# GIT
# ==========================================================================
{ inputs, ... }: {
  flake.modules.homeManager.git = { ... }: {
    programs.git = {
      enable = true;
      settings.user.name = "elichall";
      settings.user.email = "1elijah.hall@gmail.com";
    };
  };
}
