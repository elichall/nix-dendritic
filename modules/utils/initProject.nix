# ==========================================================================
# INIT-PROJECT
# ==========================================================================
# Scaffolds a new project for the nix/python/cpp core stack: git repo,
# minimal flake devShell, direnv wiring, agent dirs.
# writeShellApplication so shellcheck runs at build time. File templates are
# writeText (not heredocs) so nil formatting can never misalign delimiters;
# content is indented level with the closing '' so Nix strips it to flush.
# Usage:
#   init-project        # minimal scaffold (existing behavior)
#   init-project --python  # Python core stack (numpy, pandas, etc. + basedpyright + clangd)
#   init-project --cpp     # C++ core stack (gcc, clang, clangd + basedpyright)
{ self, ... }: {
  flake.modules.homeManager.initProject =
    { pkgs, lib, ... }:
    let
      system = "x86_64-linux";

      # shellHook bodies are defined as Nix strings, then wrapped with literal
      # '' delimiters and interpolated into the flake templates below. Building
      # the shellHook attribute via concatenation (shellHookAttr) avoids nesting
      # literal '' delimiters inside a writeText ''...'' block, which would
      # otherwise terminate the outer string prematurely.
      pythonShellHook = ''
        mkdir -p app
        # Basedpyright + clangd are available on PATH for polyglot projects
        export PYRIGHT_ENABLE_STRUCTURAL_SUBTYPING=true
      '';

      cppShellHook = ''
        mkdir -p build
        # Basedpyright + clangd available for mixed Python/C++ workflows
      '';

      pythonShellHookAttr = "shellHook = ''" + pythonShellHook + "'';";
      cppShellHookAttr = "shellHook = ''" + cppShellHook + "'';";

      # ---- language-specific flake.nix templates ---------------------------- #
      pythonFlake = pkgs.writeText "flake.nix" ''
        {
          inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

          outputs = { self, nixpkgs }:
            let
              pkgs = nixpkgs.legacyPackages.''${system};
            in
            {
              devShells.''${system}.default = pkgs.mkShell {
                nativeBuildInputs = with pkgs; [
                  basedpyright
                  (python3.withPackages (
                    ps: with ps; [
                      numpy
                      matplotlib
                      pandas
                      scipy
                    ]
                  ))
                ];
                ${pythonShellHookAttr}
              };
              options = {};
            };
        }
      '';

      cppFlake = pkgs.writeText "flake.nix" ''
        {
          inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

          outputs = { self, nixpkgs }:
            let
              pkgs = nixpkgs.legacyPackages.''${system};
            in
            {
              devShells.''${system}.default = pkgs.mkShell {
                nativeBuildInputs = with pkgs; [
                  basedpyright
                  clangd
                  cmake
                ];
                ${cppShellHookAttr}
              };
              options = {};
            };
        }
      '';

      minimalFlake = pkgs.writeText "flake.nix" ''
        {
          inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

          outputs = { self, nixpkgs }:
            let
              system = "x86_64-linux";
              pkgs = nixpkgs.legacyPackages.''${system};
            in
            {
              devShells.''${system}.default = pkgs.mkShell {
                packages = with pkgs; [ ];
              };
            };
        }
      '';

      # ---- language-specific gitignore templates -------------------------- #
      pythonGitignore = pkgs.writeText "gitignore" ''
        # Development Environment
        .direnv/
        .envrc
        .cache/
        build/

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

        # Assets
        dev/
        notes/
        logs/

        # Agent Files (opencode structure)
        AGENTS.md
        TODO.md
        .agents/

        # Nix Env
        result/
      '';

      cppGitignore = pkgs.writeText "gitignore" ''
        # Development Environment
        .direnv/
        .envrc
        .cache/
        build/

        # Cpp Env
        vendor/
        compile_commands.json

        # Assets
        dev/
        notes/
        logs/

        # Agent Files (opencode structure)
        AGENTS.md
        TODO.md
        .agents/

        # Nix Env
        result/
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

          # Select templates based on CLI flag (default: minimal scaffold)
          case "''${1:-}" in
            --python)
              flake_src="${pythonFlake}"
              gitignore_src="${pythonGitignore}"
              ;;
            --cpp)
              flake_src="${cppFlake}"
              gitignore_src="${cppGitignore}"
              ;;
            *)
              flake_src="${minimalFlake}"
              gitignore_src="${gitignore}"
              ;;
          esac

          if [ -d .git ]; then
            echo "init-project: refusing to run in an existing git repo" >&2
            exit 1
          fi

          ${lib.getExe pkgs.git} init -b main

          mkdir -p src .agents
          touch AGENTS.md

          echo "use flake" > .envrc
          ${lib.getExe' pkgs.coreutils "cp"} "''${flake_src}" flake.nix
          ${lib.getExe' pkgs.coreutils "cp"} "''${gitignore_src}" .gitignore

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
