{ inputs, config, ... }: {
  flake.homeConfigurations.macos = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
    extraSpecialArgs = { inherit inputs; };

    modules = [ ];
  };
}
