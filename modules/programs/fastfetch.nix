# ==========================================================================
# FASTFETCH
# ==========================================================================
# User-scale (Home Manager) only: binary exposure for showoff-layout / waybar
# user scripts (dependency self-containment — see AGENTS.md Rule 4) + reserved
# for future fastfetch config (theme.jsonc), empty until then.
{ inputs, ... }: {

  flake.modules.homeManager.fastfetch = { pkgs, ... }: {
    home.packages = [ pkgs.fastfetch ];
    # placeholder for fastfetch user config (Phase 3 theme-adjacent)
  };
}
