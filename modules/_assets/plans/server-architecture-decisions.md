# Server Architecture Evaluation & Constraints

## 1. Hardware & Virtualization Physics Constraints
* **PCIe Passthrough on T480:** Laptop Platform Controller Hub (PCH) architectures tightly couple PCIe lanes. The native Intel GbE controller shares IOMMU groups with critical system buses (USB, NVMe). Strict VFIO PCI passthrough of the WAN interface to a VM is structurally unviable and will cause host OS instability.
* **Thunderbolt VFIO:** Thunderbolt 3 Ethernet adapters under VFIO passthrough exhibit severe instability during hot-plug events or host sleep states.
* **Docker Compose vs. Native Modules:** Deploying Docker Compose on NixOS bypasses the Nix module system, creating unmanaged mutable state.

## 2. Decision Log

### 2.1. Hypervisor Architecture
* **Decision:** Bare-metal NixOS acting as the host OS and hypervisor. Proxmox VE is rejected.
* **Justification:** Maintaining a monolithic repository requires end-to-end declarative control. Introducing Proxmox fragments the infrastructure. A physical T480 (4C/8T, 24GB RAM) possesses limited compute overhead; bare-metal NixOS minimizes hypervisor footprint.
* **Status:** Settled.

### 2.2. Router/Gateway Implementation
* **Decision:** Native NixOS routing utilizing `networking.nftables` (already enabled on workstation) and native DHCP/DNS services (`services.dnsmasq`).
* **Justification:** Avoids IOMMU/VFIO hardware limitations entirely. Native NixOS routing eliminates the VM overhead, maximizes GbE line-rate throughput, and keeps firewall/NAT configuration strictly declarative within the dendritic repo structure.
* **Verified:**
  * `networking.nftables.enable` — exists in nixos-26.05 (`nix eval` returns `true`, already active on workstation).
  * `services.dnsmasq.enable` — exists in nixos-26.05 (`nix eval` returns `false`, default off).
  * `services.kea` — **does NOT exist** in nixos-26.05. Dropped from scope.
* **Status:** Settled.

### 2.3. Service Placement & Aspect Boundaries
* **Decision:** Utilize native `services.<name>` modules. Services to implement: `services.nextcloud`, `networking.wireguard`, `services.adguardhome`. Aggregate these into a new group: `nixos.server`.
* **Justification:** Native modules evaluate against `nixpkgs` and generate optimized systemd services. Modules like `services.nextcloud` natively provision and wire database (`services.mysql`, which is MariaDB in nixpkgs) and cache (`services.redis.servers`) dependencies declaratively. This adheres to repo Rule 4 (dependency self-containment) and avoids OCI container black boxes.
* **Verified (nixos-26.05 option paths):**
  * `services.nextcloud.enable` — exists (`nix eval` returns `false`, default off).
  * `networking.wireguard.interfaces` — exists (returns `{ }`, no instances configured). WireGuard is kernel-native; configured via `networking.wireguard`, not a separate `services.wireguard`.
  * `services.adguardhome.enable` — exists (`nix eval` returns `false`, default off).
  * `services.mysql.enable` — exists (`nix eval` returns `false`). MariaDB is exposed as `services.mysql` in NixOS, not `services.mariadb`.
  * `services.redis.servers` — exists (returns `{ }`). The old `services.redis.enable` is deprecated; current path is `services.redis.servers.<name>.enable`.
* **Group naming:** Uses `nixos.server` (lowercase) to match existing convention (`nixos.base`, `nixos.desktop`). The original draft used `nixos.serverStack` — corrected.
* **Status:** Settled.

### 2.4. Dual-Identity Risk Mitigation
* **Decision:** Validate the server stack using `nixos-rebuild build-vm --flake .#server`.
* **Justification:** Compiles the `server.nix` configuration into an isolated QEMU VM script. Permits functional testing of the router/networking stack utilizing the physical Thunderbolt adapter without altering the `workstation` host bootloader or NVMe filesystem.
* **Verified:** The NixOS qemu-vm module (`nixos/modules/virtualisation/qemu-vm.nix:1472`) overrides `fileSystems` via `mkVMOverride`, meaning hardware-specific `fileSystems` entries from the T480 config are correctly disregarded inside the VM. `build-vm` is safe to use even when the server config imports the same hardware module as the workstation.
* **Status:** Settled.

### 2.5. Storage & Hardware-Key Registry
* **Decision:** Defer the `nixos.hardwareConfig` rename. Both `server.nix` and `workstation.nix` share the same T480 hardware (same disk, same UUIDs) during the prototype phase, so both should import `nixos.hardwareConfig` as-is. Rename/split only when migrating to dedicated server hardware with a distinct disk layout.
* **Justification:** The original proposal to create `nixos.hardware-t480-workstation` and `nixos.hardware-t480-server-ext4` is architecturally correct for distinct hardware, but premature while both hosts run on the same physical T480 — they would define identical `fileSystems` entries, making the duplication pointless. When dedicated server hardware is acquired, create `nixos.hardware-<newTarget>` and update the single import line in `server.nix`. The `nixos.hardwareConfig` key name stays as-is until then.
* **Status:** Deferred (resolve at hardware migration).

### 2.6. Secrets Management
* **Decision:** Introduce `sops-nix` as a flake input. Create a `nixos.sops` base aspect.
* **Justification:** WireGuard keys, Nextcloud credentials, and database passwords require encryption at rest. `sops-nix` integrates with `nixpkgs` systemd service definitions, injecting secrets via `LoadCredential`.
* **Status:** Settled.

### 2.7. Hardware Swappability
* **Decision:** Keep `server.nix` as a thin entry point importing `nixos.server`, `nixos.base`, and `nixos.hardwareConfig`.
* **Justification:** Decouples hardware constraints (disk UUIDs, kernel modules) from software topology. Future migration to a dedicated target requires writing a new `nixos.hardware-<newTarget>` aspect and updating a single import line in `server.nix`.
* **Status:** Settled.

## 3. `nixos.base` Group Scope Audit

**Problem identified:** `nixos.base` currently bundles `nixos.battery` and `nixos.audio`, which are workstation-specific:
* `nixos.battery` (TLP, dual-battery charge thresholds, CPU governor) — laptop-only.
* `nixos.audio` (PipeWire) — desktop/laptop-only; a headless server does not run an audio stack.

**Decision:** `server.nix` should **not** import `nixos.base`. Instead, import the individual headless-safe aspects directly:
* `nixos.network` — Networking, firewall, Tailscale, SSH.
* `nixos.hardware` — fstrim, fwupd, earlyoom (generic, no laptop assumptions).
* `nixos.security` — Kernel sysctl hardening.

**Future option:** Create a `nixos.serverBase` group aggregating these three, plus any server-specific additions (see §4). This keeps the host file clean while avoiding polluting the existing `nixos.base` group with conditionals.

## 4. `nixos.main` Scope Audit

**Problem identified:** `nixos.main` (`modules/configuration.nix`) contains several settings that are desktop-oriented:
* `boot.loader.systemd-boot` — valid for servers, but a headless server may prefer GRUB or a serial console.
* `services.flatpak.enable = true` — desktop-only; no use on a headless server.
* `fonts.packages` (JetBrains Mono, Noto) — desktop-only; irrelevant on headless.
* `users.users.elichall.extraGroups = [ "video" "audio" ]` — server user may not need these groups.

**Decision:** During server implementation, override these via `lib.mkForce` or `lib.mkDefault` in `server.nix` inline config (not modifying `nixos.main`):
```nix
services.flatpak.enable = lib.mkForce false;
fonts.packages = lib.mkForce [];
```
The bootloader, user groups, and locale settings are shared and stay as-is. This follows the existing pattern: host files carry host-specific overrides on top of shared aspect imports.

## 5. Filesystem Configuration Note

**Original proposal:** Create a separate `nixos.hardware-t480-server-ext4` with a different root filesystem layout.

**Correction:** On the same physical T480, the root filesystem IS ext4 — the existing `nixos.hardwareConfig` already declares `fileSystems."/" = { fsType = "ext4"; ... }`. There is no separate partition layout to model. A second hardware profile would duplicate identical `fileSystems` entries for no benefit. Deferred to hardware migration (§2.5).
