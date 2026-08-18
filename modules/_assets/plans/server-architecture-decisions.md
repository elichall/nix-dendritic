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
* **Decision:** Native NixOS routing utilizing `networking.nftables` and native DHCP/DNS services (e.g., `services.dnsmasq` or `services.kea`).
* **Justification:** Avoids IOMMU/VFIO hardware limitations entirely. Native NixOS routing eliminates the VM overhead, maximizes GbE line-rate throughput, and keeps firewall/NAT configuration strictly declarative within the dendritic repo structure.
* **Status:** Settled.

### 2.3. Service Placement & Aspect Boundaries
* **Decision:** Utilize native `services.<name>` modules. Services to implement: `nixos.nextcloud`, `nixos.wireguard`, `nixos.adguardHome` (replaces Pi-hole). Aggregate these into a new group: `nixos.serverStack`.
* **Justification:** Native modules evaluate against `nixpkgs` and generate optimized systemd services. Modules like `services.nextcloud` natively provision and wire database (MariaDB) and cache (Redis) dependencies declaratively. This adheres to repo Rule 4 (dependency self-containment) and avoids OCI container black boxes.
* **Status:** Settled.

### 2.4. Dual-Identity Risk Mitigation
* **Decision:** Validate the server stack using `nixos-rebuild build-vm --flake .#server`.
* **Justification:** Compiles the `server.nix` configuration into an isolated QEMU VM script. Permits functional testing of the router/networking stack utilizing the physical Thunderbolt adapter without altering the `workstation` host bootloader or NVMe filesystem.
* **Status:** Settled.

### 2.5. Storage & Hardware-Key Registry
* **Decision:** Deprecate the single `nixos.hardwareConfig` key. Refactor into `nixos.hardware-t480-workstation` and `nixos.hardware-t480-server-ext4`. `server.nix` will utilize the ext4 profile during the prototype phase.
* **Justification:** Rule 2 dictates path-agnostic builds. A generalized `hardwareConfig` key creates namespace collisions when hosts require distinct layouts. Distinct hardware aspects maintain strict scope separation. Prototyping on ext4 defers ZFS complexities until the dedicated hardware and external DAS are acquired.
* **Status:** Settled.

### 2.6. Secrets Management
* **Decision:** Introduce `sops-nix` as a flake input. Create a `nixos.sops` base aspect.
* **Justification:** WireGuard keys, Nextcloud credentials, and database passwords require encryption at rest. `sops-nix` integrates with `nixpkgs` systemd service definitions, injecting secrets via `LoadCredential`.
* **Status:** Settled.

### 2.7. Hardware Swappability
* **Decision:** Keep `server.nix` as a thin entry point importing `nixos.serverStack`, `nixos.base`, and `nixos.hardware-t480-server-ext4`.
* **Justification:** Decouples hardware constraints (disk UUIDs, kernel modules) from software topology. Future migration to a dedicated target requires writing a new `nixos.hardware-<newTarget>` aspect and updating a single import line in `server.nix`.
* **Status:** Settled.
