# Nix Hybrid Development Framework

This document outlines our unified development environment using **Nix Flakes**, **devenv**, and **direnv**. 

This hybrid architecture gives us the best of both worlds:
1. **Nix Flakes (`flake.nix`)**: Handles the complex system plumbing, pinning exact dependency channels, and locks down the environment reproducibly via `flake.lock`.
2. **Devenv (`devenv.nix`)**: Acts as a human-readable dashboard for the team. Anyone can easily add standard languages, packages, or background services without needing to learn advanced Nix.
3. **Direnv (`.envrc`)**: Seamlessly activates and deactivates the environment automatically as you `cd` in and out of the project directory.

---

## Architecture Overview

```
Your Project Root
├── flake.nix        <-- Plumbing (Managed by Nix-savvy developers)
├── flake.lock       <-- Version Lock (Automated, do not edit manually)
├── devenv.nix       <-- Dashboard (Managed by the whole team to add tools)
├── devenv.yaml      <-- Global Options (Configures allowUnfree or caching)
└── .envrc           <-- Automation (Tells direnv how to load the environment)
```

---

## Configuration Templates

Copy and paste these boilerplates directly into your new project root.

### 1. `flake.nix` (The Infrastructure)
This file defines our inputs, pins `nixpkgs`, and configures the system architectures. It imports `devenv.nix` dynamically.

```nix
{
  description = "Unified Project Developer Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devenv.url = "github:cachix/devenv";
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, nixpkgs, devenv, systems, ... } @ inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in {
      devShells = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              # Core environment configuration that the team edits
              ./devenv.nix
              
              # Advanced or protected configurations can be declared here
              ({ pkgs, ... }: {
                # Add strict system-level environment variables here if necessary
                env.PROJECT_INFRA_ENGINE = "pure-nix-flakes";
              })
            ];
          };
        });
    };
}
```

### 2. `devenv.nix` (The Team Dashboard)
**This is the file most developers will interact with.** If you need to switch language versions, add an ecosystem utility, or turn on a database service, edit this file.

```nix
{ pkgs, lib, config, ... }: {
  
  # 1. Environment Variables
  env.DEVELOPMENT_ENVIRONMENT = "hybrid-nix-devenv";

  # 2. Command Line Utilities / Packages
  # Browse package options at: https://search.nixos.org/packages
  packages = [
    pkgs.git
    pkgs.htop
    pkgs.jq
    pkgs.ripgrep
  ];

  # 3. Programming Languages and Toolchains
  # Supported languages list: https://devenv.sh/languages/
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_22;
    corepack.enable = true; # Enables yarn / pnpm out-of-the-box
  };

  languages.python = {
    enable = true;
    venv.enable = true;
    venv.requirements = ./requirements.txt; # Optional: auto-installs pip requirements
  };

  # 4. Background Services (Spawns and kills services with your shell)
  # Supported services list: https://devenv.sh/services/
  services.postgres = {
    enable = false; # Toggle to true if your project requires a database
    package = pkgs.postgresql_16;
    initialScript = "CREATE USER team WITH PASSWORD 'password' SUPERUSER;";
  };

  # 5. Pre-commit Hooks (Ensures formatting/linting code runs before commits)
  pre-commit.hooks = {
    shellcheck.enable = true;
    nixpkgs-fmt.enable = true; # Keeps our Nix formats clean
  };

  # 6. Scripts / Custom Shell Commands
  # Defines wrapper aliases easily accessible in this shell environment
  scripts.project-info.exec = ''
    echo "🚀 Welcome to the Project Environment!"
    echo "Node version: $(node --version)"
    echo "Python version: $(python --version)"
  '';

  # Runs automatically whenever the shell switches on
  enterShell = ''
    project-info
  '';
}
```

### 3. `devenv.yaml` (Meta Configuration)
Required by `devenv` to track structural metadata and set local policies like allowing non-free software packages.

```yaml
inputs:
  nixpkgs:
    url: github:NixOS/nixpkgs/nixos-unstable
allowUnfree: true
```

### 4. `.envrc` (The Shell Automation)
This file triggers `direnv` to read your Nix setup automatically when you open a terminal in this project.

```bash
# Instructs direnv to evaluate our master flake output
use flake
```

---

## Getting Started Workflow

Follow these steps when checking out this repository or initializing it on a team machine:

1. **Install Nix & Direnv**: Ensure Nix (with flakes enabled) and `direnv` are installed on your native machine.
2. **Allow the Directory**: Run the following command in the project root:
   ```bash
   direnv allow
   ```
3. **Wait for Hook Cache**: On the first load, `nix-direnv` will build the package specifications and register them into a safe Garbage Collection (GC) root local to `.direnv/`. Subsequent directory loads will be instant.
4. **Modifying the Environment**: Open `devenv.nix`, toggle or add what you need, and save. The shell environment will immediately reload in the background.
