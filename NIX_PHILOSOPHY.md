# Strategic Architecture: Nix in Computational & Physical Systems

## Core Philosophy: Nix as Substrate, Not Execution Engine

Nix is a strictly functional deployment model designed for deterministic system states. It is not an optimal package manager for rapidly mutating, highly coupled execution runtimes. Applying pure Nix derivations to transient machine learning environments or complex robotics graphs constitutes over-engineering and leads to severe evaluation scaling penalties.

To maintain pragmatism and efficiency, treat Nix as the Layer 0/1 infrastructure orchestrator. Hard boundaries must be enforced between hermetic system configuration and dynamic application state.

### Architectural Layers

1.  **Layer 0 - Bare Metal & Infrastructure:** NixOS host definitions, declarative network topology, kernel modules, and ZFS state. Managed via pure flake outputs.
2.  **Layer 1 - Hermetic Toolchains:** Standardized C++ compilation environments, pinned CMake configurations, and embedded microcontroller toolchains. Managed via `devShells`.
3.  **Layer 2 - Execution Units:** OCI container generation and hermetic build system (Bazel) orchestrations. Nix constructs the environments; the specialized tools execute the workflows.
4.  **Layer 3 - Dynamic Runtimes:** Fast-moving Python/CUDA workflows and ROS 2 execution graphs. Managed via standard industry tools (`uv`, `pixi`, standard virtualenvs) executed *within* Nix-provisioned FHS shells.

---

## Friction Points & Engineering Standard Practices

### Machine Learning (CUDA / JAX)
*   **Constraint:** Compiling ML libraries from source via pure Nix scales poorly in both RAM and time due to massive dependency trees and compute-specific binary blobs.
*   **Solution:** Provision system-level CUDA runtimes and hardware drivers via Nix. Utilize `buildFHSEnv` to construct a POSIX-compliant sandbox. Delegate all Python package resolution to standard `uv` or `pip` utilizing pre-compiled `.whl` binaries.

### Robotics & Embedded Control
*   **Constraint:** Robotics frameworks (ROS 2) expect standard Ubuntu LTS filesystem layouts. Pure Nix packaging requires maintaining hundreds of custom derivations for transient nodes.
*   **Solution:** Utilize pure Nix shells for bare-metal microcontroller firmware development (e.g., C++/PlatformIO for LQR reaction wheels). For higher-level robotics graphs, use Nix `dockerTools` to generate deterministic OCI images, isolating the FHS-dependent nodes from the host.

### Build Orchestration (Bazel)
*   **Constraint:** Integrating Nix evaluation directly into remote execution (RBE) Bazel graphs causes path-resolution failures across distributed workers.
*   **Solution:** Nix defines the base worker container and initial compiler toolchain. Bazel handles the internal action-graph caching and compilation parallelization.

---

## Skeleton Architecture: `flake.nix`

```nix
{
  description = "Multi-domain computational physics and robotics infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      
      # ---------------------------------------------------------
      # Layer 1 Hermetic Toolchains: Development Shells
      # ---------------------------------------------------------
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              cudaSupport = true;
            };
          };

          # ---------------------------------------------------------
          # Layer 3 Dynamic Runtime: FHS Shell for ML (CUDA / JAX)
          # ---------------------------------------------------------
          ml-fhs-env = pkgs.buildFHSEnv {
            name = "ml-fhs-env";
            targetPkgs = pkgs: with pkgs; [
              python311
              uv
              git
              # System-level dependencies required by pre-compiled wheels
              zlib
              glib
              libGL
              stdenv.cc.cc.lib
            ];
            runScript = "bash";
            profile = ''
              export CUDA_PATH=${pkgs.cudatoolkit}
              export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:$LD_LIBRARY_PATH
              
              # Initialize uv environment if missing
              if [ ! -d ".venv" ]; then
                uv venv
              fi
              source .venv/bin/activate
            '';
          };
        in {
          
          # Default shell: Pure C++ and mathematical modeling
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              gcc
              cmake
              gnumake
              ninja
              gdb
            ];
          };

          # ML shell: Drops into FHS for fast iteration via uv
          ml = ml-fhs-env.env;

          # Embedded shell: Microcontroller firmware (C++/PlatformIO)
          embedded = pkgs.mkShell {
            buildInputs = with pkgs; [
              platformio
              avrdude
              picocom
            ];
            shellHook = ''
              export PLATFORMIO_CORE_DIR=$PWD/.pio
            '';
          };
        }
      );

      # ---------------------------------------------------------
      # Layer 2 Execution Units: Deterministic OCI Generation
      # ---------------------------------------------------------
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          # Example: Generating a minimal container for a compiled C++ binary
          my-physics-container = pkgs.dockerTools.buildImage {
            name = "physics-sim-node";
            tag = "latest";
            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = [ pkgs.bash pkgs.coreutils ]; # Add compiled derivations here
              pathsToLink = [ "/bin" ];
            };
            config = {
              Cmd = [ "${pkgs.bash}/bin/bash" ];
            };
          };
        }
      );
    };
}
```
