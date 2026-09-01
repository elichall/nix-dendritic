{
  description = "Multiplatform Personal Nix Setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wlctl = {
      url = "github:aashish-thapa/wlctl/v0.1.9";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    otter-launcher = {
      url = "github:kuokuo123/otter-launcher/v0.7.6";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        (inputs.import-tree ./modules)
        # Central flake pkg definition — single source of truth for the Nixpkgs
        # instance passed to hosts (which expose it via `self.pkgs.<system>`).
        #
        # WHY here: the hosts create an EXTERNAL nixpkgs instance
        # (`self.pkgs.<system>`), so a `nixpkgs.config.allowUnfree*` option in a
        # NixOS module would fail a hard assertion ("pass the config when
        # creating the instance instead"). The unfree predicate is therefore
        # baked in at import time, scoped to claude-code only.
        {
          flake.pkgs = {
            x86_64-linux = import inputs.nixpkgs {
              system = "x86_64-linux";
              config.allowUnfreePredicate = pkg: pkg.pname == "claude-code";
            };
          };
        }
      ];
    };
}
