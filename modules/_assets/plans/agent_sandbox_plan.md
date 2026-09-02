# Cross-Platform Agent Isolation Specification

## 1. Problem Statement & Architecture Constraints

Autonomous code agents and language-model-driven development tools executing within local developer environments present an exfiltration risk for sensitive inputs, raw telemetry, and experimental data. 

To prevent unauthorized read/write access to sensitive files residing outside the project workspace while retaining full developer workflow velocity across heterogeneous platforms, the following constraints must be met:

- **Monolithic Repository Compatibility:** Operates consistently across NixOS, generic Linux distributions (Debian/Ubuntu/Fedora), Windows Subsystem for Linux 2 (WSL2), and macOS (`nix-darwin`).
- **Zero Heavy Virtualization:** Eliminates overhead from nested VMs, microVMs, or root-privileged container runtimes (e.g., Docker/Podman daemon requirements).
- **Filesystem Confinement:** The agent process must have unrestricted access to the project directory, read-only access to `/nix/store` and required system runtime libraries, and complete obstruction from accessing external data directories (e.g., `~/sensitive_lab_data`).
- **Pure Flake Interface:** Evaluated and dispatched deterministically via Nix flakes without manual out-of-band configuration.

---

## 2. Kernel Primitives & Execution Mechanics

Because Linux and Darwin (macOS) expose entirely distinct security boundaries, isolation cannot rely on a single cross-platform abstraction layer.

### 2.1. Linux (Generic, NixOS, WSL2): Linux Namespaces via Bubblewrap (`bwrap`)

Linux provides resource isolation via kernel namespaces (`user_namespaces(7)`, `mount_namespaces(7)`, `pid_namespaces(7)`, `net_namespaces(7)`). 

`bubblewrap` is an unprivileged sandboxing utility leveraging unprivileged user namespaces. Rather than masking files post-facto, it constructs an isolated mount table:

1. **Mount Filtering:** The new mount namespace only contains explicitly bound targets. `/nix/store` is mounted read-only (`--ro-bind`), ensuring full access to Nix closures without write tampering.
2. **Explicit Workspace Binding:** The current project directory (`$PWD`) is bound read-write (`--bind`), scoped strictly to the development tree.
3. **Implicit Deny:** Any path on the host filesystem not explicitly bound (including parent user directories, configuration trees, and external raw data stores) physically does not exist in the isolated VFS mount table. System calls resolving outside the allowlist immediately return `ENOENT`.

*Note for WSL2/Generic Linux:* Requires unprivileged user namespaces enabled (`sysctl kernel.unprivileged_userns_clone = 1`, which is default in standard modern kernels).

### 2.2. macOS (`nix-darwin`): Mandatory Access Control (MAC) via Seatbelt (`sandbox-exec`)

macOS (XNU kernel) does not implement user or mount namespaces. Sandboxing is enforced via the TrustedBSD Mandatory Access Control framework, internally known as **Seatbelt**.

Seatbelt is configured through the Sandbox Profile Language (SBPL), evaluated directly by `/usr/bin/sandbox-exec`:

1. **Rule Evaluation:** A declarative policy sets default-allow rules for general system operations, network access, and standard toolchains.
2. **Targeted Subpath Denial:** An explicit denial rule (`(deny file-read* file-write* (subpath ...))`) hooks the VFS operations at the kernel level.
3. **Enforcement:** Any system call (e.g., `open(2)`, `stat(2)`, `readdir(3)`) addressing the restricted sensitive directory hierarchy aborts with `EPERM` (Operation not permitted).

---

## 3. Implementation Blueprint

### 3.1. Directory Structure

```text
├── flake.nix
├── flake.lock
├── scripts/
│   └── run-agent.sh
└── sensitive_data_store/          # Stored outside or excluded via path definition
    └── lab_telemetry.csv
```

### 3.2. Complete `flake.nix`

The flake below detects the evaluation target system (`pkgs.stdenv.isDarwin`) and exposes a universal executable package `agent-sandbox`:

```nix
{
  description = "Cross-platform kernel-level agent filesystem isolation sandbox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Target boundary definitions
        # External sensitive data directory to protect
        restrictedDataDir = "$HOME/sensitive_lab_data";

        # ----------------------------------------------------------------------
        # Linux Sandbox: Bubblewrap Namespace Isolation
        # ----------------------------------------------------------------------
        linuxSandbox = pkgs.writeShellScriptBin "agent-sandbox" ''
          set -euo pipefail

          PROJECT_DIR="$(pwd)"

          # Validate execution context
          if [ ! -d "$PROJECT_DIR" ]; then
            echo "Error: Working directory does not exist." >&2
            exit 1
          fi

          exec ${pkgs.bubblewrap}/bin/bwrap \
            --ro-bind /nix/store /nix/store \
            --ro-bind /etc/resolv.conf /etc/resolv.conf \
            --ro-bind-try /etc/ssl /etc/ssl \
            --ro-bind-try /etc/static/ssl /etc/static/ssl \
            --ro-bind-try /usr /usr \
            --symlink usr/lib /lib \
            --symlink usr/lib64 /lib64 \
            --symlink usr/bin /bin \
            --symlink usr/sbin /sbin \
            --proc /proc \
            --dev /dev \
            --tmpfs /tmp \
            --bind "$PROJECT_DIR" "$PROJECT_DIR" \
            --chdir "$PROJECT_DIR" \
            --unshare-all \
            --share-net \
            --die-with-parent \
            "$@"
        '';

        # ----------------------------------------------------------------------
        # macOS Sandbox: Seatbelt (sandbox-exec) SBPL Policy
        # ----------------------------------------------------------------------
        darwinSandbox = pkgs.writeShellScriptBin "agent-sandbox" ''
          set -euo pipefail

          PROJECT_DIR="$(pwd)"
          RESTRICTED_PATH="${restrictedDataDir}"
          # Resolve shell variable expansion if $HOME is passed literally
          EXPANDED_RESTRICTED="$(eval echo "$RESTRICTED_PATH")"

          # Construct SBPL Profile dynamically
          SBPL_PROFILE="(version 1)
          (allow default)
          (deny file-read* file-write* (subpath "$EXPANDED_RESTRICTED"))"

          exec /usr/bin/sandbox-exec -p "$SBPL_PROFILE" "$@"
        '';

        sandboxPkg = if pkgs.stdenv.isDarwin then darwinSandbox else linuxSandbox;

      in {
        packages = {
          default = sandboxPkg;
          agent-sandbox = sandboxPkg;
        };

        apps = {
          default = flake-utils.lib.mkApp {
            drv = sandboxPkg;
            name = "agent-sandbox";
          };
        };

        devShells.default = pkgs.mkShell {
          packages = [ sandboxPkg ];
          shellHook = ''
            echo "Agent isolation harness loaded. Run: agent-sandbox -- <command>"
          '';
        };
      }
    );
}
```

---

## 4. Usage & Execution Verification

### 4.1. Invocation

Invoke arbitrary commands, agent language models, or interactive agent shells via standard Nix workflows:

```bash
# Direct run via Flake app
nix run .#agent-sandbox -- python -m agent_runner

# Direct run within devShell
nix develop
agent-sandbox -- bash
```

### 4.2. Verification Test Suite

Run the following test commands across both target platforms to confirm boundary enforcement:

#### Test 1: Project Directory Read/Write (Must Succeed)
```bash
nix run .#agent-sandbox -- touch ./workspace-test.tmp
nix run .#agent-sandbox -- rm ./workspace-test.tmp
```

#### Test 2: External Sensitive Directory Access (Must Fail)
Ensure `~/sensitive_lab_data` exists on the host with a dummy file:
```bash
mkdir -p ~/sensitive_lab_data
echo "RESTRICTED_DATA" > ~/sensitive_lab_data/sample.csv
```

Execute containment probe:
```bash
nix run .#agent-sandbox -- cat ~/sensitive_lab_data/sample.csv
```

**Expected Responses:**
- **Linux / WSL2:** `cat: /home/<user>/sensitive_lab_data/sample.csv: No such file or directory` (Mount namespace obstruction).
- **macOS:** `cat: /Users/<user>/sensitive_lab_data/sample.csv: Operation not permitted` (Seatbelt MAC obstruction).

---

## 5. Security Limitations & Verification Metrics

1. **Seatbelt Deprecation Notice:** Apple flags `/usr/bin/sandbox-exec` as deprecated in macOS release notes, but it remains fully operational in modern macOS versions (including Sequoia 15.x). It remains the foundational backend used by Nix itself to construct isolated store derivations on Darwin systems.
2. **Network Filtering:** The provided configuration passes `--share-net` on Linux and default network access on macOS to allow agents to contact remote LLM APIs. If the agent itself is untrusted and must not communicate externally, remove `--share-net` on Linux and add `(deny network*)` to the Darwin SBPL profile.
3. **Symlink Traversal:** Ensure symlinks inside the project directory do not point directly into `~/sensitive_lab_data`. Bubblewrap ignores target paths outside its mounts (resulting in a broken symlink), while Seatbelt evaluates the canonical target path and terminates access.
