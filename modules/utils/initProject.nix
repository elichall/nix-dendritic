# ==========================================================================
# INIT-PROJECT
# ==========================================================================
# Scaffolds a new project for the nix/python/cpp core stack: git repo,
# minimal flake devShell, direnv wiring, agent dirs.
# writeShellApplication so shellcheck runs at build time. File templates are
# writeText (not heredocs) so nil formatting can never misalign delimiters;
# content is indented level with the closing '' so Nix strips it to flush.
{ self, ... }: {
  flake.modules.homeManager.initProject =
    { pkgs, lib, ... }:
    let
      flakeNix = pkgs.writeText "flake.nix" ''
        {
          inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

          outputs = { self, nixpkgs }:
            let
              system = "x86_64-linux";
              pkgs = nixpkgs.legacyPackages.''${system};
            in {
              devShells.''${system}.default = pkgs.mkShell {
                packages = with pkgs; [ ];
              };
            };
        }
      '';

      gitignore = pkgs.writeText "gitignore" ''
        # Development Environment
        .direnv/
        .envrc
        .cache/
        build/

        # Assets
        dev/
        notes/
        logs/
        data/

        # Agent Files (opencode structure)
        AGENTS.md
        TODO.md
        .agents/

        # Nix Env
        result/

        # Python Env
        venv/
        .venv/
        env/
        .env/
        *.egg-info/
        dist/
        __pypackages__/
        __pycache__/
        .pytest_cache/
        pyrightconfig.json

        # Cpp Env
        vendor/
        compile_commands.json
      '';

      initProjectCLI = pkgs.writeShellApplication {
        name = "init-project";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.git
          pkgs.direnv
        ];
        text = ''
          set -euo pipefail

          if [ -d .git ]; then
            echo "init-project: refusing to run in an existing git repo" >&2
            exit 1
          fi

          ${lib.getExe pkgs.git} init -b main

          mkdir -p src .agents
          touch AGENTS.md

          echo "use flake" > .envrc
          ${lib.getExe' pkgs.coreutils "cp"} "${flakeNix}" flake.nix
          ${lib.getExe' pkgs.coreutils "cp"} "${gitignore}" .gitignore

          ${lib.getExe pkgs.direnv} allow

          ${lib.getExe pkgs.git} add -A
          ${lib.getExe pkgs.git} commit -m "Initialized project"
        '';
      };
    in
    {
      home.packages = [
        initProjectCLI
        pkgs.git
        pkgs.direnv
      ];
    };
}
