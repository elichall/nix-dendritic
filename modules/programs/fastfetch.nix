# ==========================================================================
# FASTFETCH
# ==========================================================================
# System-scale (NixOS): binary exposure so showoff-layout / waybar user
# scripts reach it via PATH. User-scale (Home Manager): reserved for future
# fastfetch config (theme.jsonc), empty until then.
{ inputs, ... }: {
  flake.modules.nixos.fastfetch = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.fastfetch ];
  };

  flake.modules.homeManager.fastfetch = { ... }: {
    # placeholder for fastfetch user config (Phase 3 theme-adjacent)
  };
}
