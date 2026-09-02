# Packaging & Distributing Nix Applications to Non-Nix Users

When shipping applications developed within a Nix flake to coworkers who require a download-and-run binary without a local Nix installation, the workflow shifts from using `devShells` to building explicit package derivations (`buildPythonApplication`), which can then be bundled into standard formats.

---

## 1. Package Derivation Setup (`flake.nix`)

Define the application under `packages` in `flake.nix` to assemble dependencies, CLI entry points, and vendored assets into the standard Nix store structure.

```nix
packages = forAllSystems (system:
  let
    pkgs = nixpkgs.legacyPackages.${system};
    python = pkgs.python3;
  in {
    default = python.pkgs.buildPythonApplication {
      pname = "constitutive-calibrator";
      version = "0.1.0";
      src = ./.;

      propagatedBuildInputs = with python.pkgs; [
        scipy numpy pandas fastapi uvicorn pydantic openpyxl pyarrow tkinter
      ];

      # Copy the content-addressed plotly.min.js into place during build
      postInstall = ''
        mkdir -p $out/lib/python*/site-packages/app/frontend/vendor
        cp ${plotlyJs pkgs} $out/lib/python*/site-packages/app/frontend/vendor/plotly.min.js
      '';

      doCheck = false;
    };
  }
);
```

---

## 2. Distribution Strategies

### Option A: AppImage via `nix-appimage` (Linux Targets)
For coworkers on standard Linux distributions (Ubuntu, RHEL, Fedora, Debian).

* **Mechanism**: Bundles the entire `/nix/store` runtime closure into an executable squashfs utilizing user namespaces (`userns-chroot`). Zero host dependencies and no root required.
* **Build Command**:
  ```bash
  nix bundle --bundler github:ralismark/nix-appimage .#default
  ```
* **Distribution**: Distribute the resulting `.AppImage` binary. Users run it via `./constitutive-calibrator.AppImage` or a direct double-click.

---

### Option B: Layered OCI/Docker Container via `dockerTools` (Cross-Platform / Web GUI)
For running the local FastAPI/uvicorn server across platforms (Linux, macOS, Windows via Docker Desktop/WSL2).

* **Mechanism**: Builds bit-reproducible OCI/Docker tar archives natively via Nix without needing the Docker daemon running.
* **Flake Definition**:
  ```nix
  docker = pkgs.dockerTools.buildLayeredImage {
    name = "constitutive-calibrator";
    tag = "latest";
    contents = [ self.packages.${system}.default pkgs.coreutils ];
    config = {
      Cmd = [ "uvicorn" "app.main:app" "--host" "0.0.0.0" "--port" "8000" ];
      ExposedPorts = { "8000/tcp" = {}; };
    };
  };
  ```
* **Build & Export**:
  ```bash
  nix build .#docker
  docker load < result
  docker run -p 8000:8000 constitutive-calibrator:latest
  ```

---

### Option C: PyInstaller via GitHub Actions CI (Native Windows / macOS)
For coworkers on native Windows who cannot run Linux binaries or Docker containers.

* **Trade-off**: Forgoes Nix store bit-reproducibility on target hosts, but outputs standard native executables (`.exe` or macOS `.app`).
* **Implementation**: Maintain a standard `pyproject.toml` or `requirements.txt` synced with the flake dependencies. Build multi-platform targets in CI via PyInstaller:
  ```bash
  pyinstaller --noconfirm --onedir --windowed \
    --add-data "app/frontend;app/frontend" \
    app/main.py
  ```

---

## 3. Comparison Matrix

| Strategy | Output Artifact | Target Environment | End-User Friction | Host Nix Required? |
| :--- | :--- | :--- | :--- | :--- |
| **`nix-appimage`** | Executable `.AppImage` | Linux | Low (Double-click execution) | No |
| **`dockerTools`** | OCI Image archive (`tar.gz`) | Cross-platform (Docker/Podman) | Medium (`docker run`) | No |
| **PyInstaller (CI)** | Directory / `.exe` / `.app` | Native Windows / macOS | Minimal (Standard OS executable) | No |
