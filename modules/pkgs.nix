# ==========================================================================
# CENTRAL NIXPKGS INSTANCE
# ==========================================================================
# Single source of truth for the Nixpkgs instance passed to hosts (which
# expose it via `self.pkgs.<system>`).
#
# WHY here: the hosts create an EXTERNAL nixpkgs instance (`self.pkgs.<system>`),
# so a `nixpkgs.config.allowUnfree*` option in a NixOS module would fail a
# hard assertion ("pass the config when creating the instance instead"). The
# unfree predicate is therefore baked in at import time, scoped to
# claude-code only.
#
# claude-code ships frequent releases, so it's tracked from nixpkgs-unstable
# via the overlay below; everything else stays pinned to the stable channel.
{ inputs, self, ... }: {
  flake.overlays.claude-code-unstable = final: _prev: {
    claude-code =
      (import inputs.nixpkgs-unstable {
        system = final.stdenv.hostPlatform.system;
        config.allowUnfreePredicate = pkg: pkg.pname == "claude-code";
      }).claude-code;
  };

  flake.pkgs.x86_64-linux = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfreePredicate = pkg: pkg.pname == "claude-code";
    overlays = [ self.overlays.claude-code-unstable ];
  };
}
