# ==========================================================================
# NEOVIM
# ==========================================================================
# System package exposure plus user-level editor session variables and the
# global LSP servers used by the editor (always on PATH).
{ inputs, ... }: {
  flake.modules.nixos.nvim = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.neovim ];
  };

  flake.modules.homeManager.nvim = { config, pkgs, ... }: {
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      SUDO_EDITOR = "nvim";
    };

    home.packages = with pkgs; [
      nil # nix
      marksman # markdown
      lua-language-server # lua
      texlab # latex
      bash-language-server # bash
    ];
  };
}
