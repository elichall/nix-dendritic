# ==========================================================================
# FASTFETCH
# ==========================================================================
# User-scale (Home Manager) only: binary exposure for showoff-layout / waybar
# user scripts + chafa block-image NixOS logo. fastfetch dlopens libchafa at
# runtime but ships it in its own closure, so no extra home.packages chafa dep
# (Rule 4 n/a).
# Plan: modules/_assets/plans/fastfetch-customization.md
{ inputs, ... }: {

  flake.modules.homeManager.fastfetch = { config, ... }: {
    programs.fastfetch = {
      enable = true;
      settings = {
        logo = {
          source = "${config.home.homeDirectory}/.nix/modules/_assets/aesthetics/nixos-image.png";
          type = "chafa";
          width = 40;
          # height omitted: auto-detect from aspect ratio (schema requires
          # null or >= 1; 0 errors "Logo height must be a positive integer")
          padding = {
            top = 1;
            right = 1;
          };
          chafa = {
            # "semi" is NOT a valid chafa symbol tag (parse_symbol_tag has no
            # such entry) — fastfetch passed it raw, chafa rejected it, and
            # fastfetch echoed "Unrecognized symbol tag 'semi'." to stderr.
            # "block" only (full-color blocks); canvas key is not in the schema
            # (fgOnly/symbols/canvasMode/colorSpace/ditherMode), so dropped.
            symbols = "block";
          };
        };
        # fastfetch 2.63.1: when a config file is loaded it prints ONLY the
        # modules listed in `modules` — a config lacking the key prints nothing
        # but the logo (no default-structure fallback, see jsonconfig.c
        # printJsonConfig). List = `fastfetch --print-structure`.
        modules = [
          "title"
          "separator"
          "os"
          "host"
          "kernel"
          "uptime"
          "packages"
          "shell"
          "display"
          "de"
          "wm"
          "wmtheme"
          "theme"
          "icons"
          "font"
          "cursor"
          "terminal"
          "termfont"
          "cpu"
          "gpu"
          "memory"
          "swap"
          "disk"
          "localip"
          "battery"
          "poweradapter"
          "locale"
          "break"
          "colors"
        ];
      };
    };
  };
}
