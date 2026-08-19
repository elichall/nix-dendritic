# Native Nix VMs for Sandboxing — Aspect Module Plan

## 1. Fundamentals: The Isolation Spectrum

Before choosing an approach, it helps to understand what "sandboxing" actually means
and where each method sits on the spectrum.

### 1.1 What Is Isolation?

Every program you run shares the same operating system: the same kernel, the same
filesystem, the same network stack, the same memory address space. Isolation is
the practice of giving a program its own *partial* copy of these resources so that
what it does doesn't affect anything else.

There are four layers, from lightest to heaviest:

```
┌─────────────────────────────────────────────────────────────────┐
│  Level 1: ENVIRONMENT / DEPENDENCY ISOLATION                    │
│  Boundary: Environment variables & file paths ($PATH,           │
│            $LD_LIBRARY_PATH)                                    │
│  → nix-shell, nix develop, buildFHSEnv                         │
│                                                                 │
│  What's shared: host kernel, host filesystem, host network,     │
│                 host process tree                               │
│  What's separate: nothing — this is NOT a security boundary     │
├─────────────────────────────────────────────────────────────────┤
│  Level 2: OS-LEVEL VIRTUALIZATION (Containers / Namespaces)     │
│  Boundary: Linux namespaces + cgroups + seccomp                 │
│  → Docker, Podman, NixOS containers (nspawn)                    │
│                                                                 │
│  What's shared: the host Linux kernel                           │
│  What's separate: PID tree, mount table, network stack, user IDs│
│  Overhead: ~0% CPU, minimal RAM (~15-50MB)                      │
├─────────────────────────────────────────────────────────────────┤
│  Level 3: MICROVMs                                              │
│  Boundary: Minimal virtualized hardware + separate Linux kernel │
│  → Firecracker, Cloud-Hypervisor, QEMU-microvm, microvm.nix    │
│                                                                 │
│  What's shared: host CPU execution (via KVM), paravirt devices  │
│  What's separate: entire OS, kernel, memory space, network, I/O │
│  Overhead: <5% CPU, ~64-128MB RAM, boot <500ms                 │
├─────────────────────────────────────────────────────────────────┤
│  Level 4: FULL HARDWARE VIRTUALIZATION (Traditional VMs)        │
│  Boundary: Complete hardware emulation / hypervisor             │
│  → QEMU/KVM full VMs, libvirtd VMs, vmVariant                  │
│                                                                 │
│  What's shared: physical CPU/RAM via hardware-assisted virt     │
│  What's separate: complete hardware rig (BIOS/UEFI, PCI, disks,│
│                   NICs, boot chain)                              │
│  Overhead: 2-5% CPU, dedicated RAM block (512MB+), boot 5-15s  │
└─────────────────────────────────────────────────────────────────┘
```

**Level 1** (nix-shell / nix develop) is worth mentioning because it's what you
already use daily for builds. It pins dependencies into `$PATH` and
`$LD_LIBRARY_PATH` so builds are reproducible. But it provides *zero isolation* —
the process runs as your user, sees your full filesystem, and has full network
access. Not a sandbox.

**Level 3** (microVMs) is a middle ground that's gaining traction in the Nix
ecosystem. Projects like [microvm.nix](https://github.com/astro/microvm.nix)
compile NixOS configs directly into stripped-down QEMU or Firecracker VMs that
boot in under 500ms with ~64-128MB RAM overhead. They discard legacy hardware
emulation (no PCI buses, no ACPI tables, no IDE controllers) and boot a tailored
kernel directly. This gives you VM-grade isolation with near-container startup
times. Worth considering if the full vmVariant overhead proves too heavy for
frequent sandbox use.

### 1.2 Containers vs. VMs vs. MicroVMs — The Core Tradeoff

**Containers** are fast and light. A container is just a regular process that the
kernel has been told "you can't see or touch anything outside your namespace." The
container runs the *same kernel* as the host. This means:

- Startup in under 1 second
- Near-zero CPU overhead
- But: if the container's kernel interface is compromised, the host is compromised
  (container escape). A root user inside a container can sometimes affect the host.

**MicroVMs** are a middle ground. They run their own kernel (like a VM) but strip
away all legacy hardware emulation, booting a minimal Linux in under 500ms. The
Nix ecosystem has `microvm.nix` for this. Tradeoffs:

- Boot in <500ms, ~64-128MB RAM overhead
- Full kernel isolation (compromise of the guest kernel does NOT compromise the host)
- But: less flexible than full VMs (no snapshots, limited device support)

**VMs** are slower and heavier but genuinely separate. A VM runs its *own kernel*
inside a hardware-enforced boundary (Intel VT-x / AMD-V). The hypervisor (QEMU
backed by KVM) mediates everything. This means:

- Startup in 5-15 seconds
- 2-5% CPU overhead for compute, dedicated RAM allocation
- But: even if the guest kernel is fully compromised, the host is unaffected
  (short of a hypervisor-level exploit, which is rare and actively patched)

**Rule of thumb:** Use containers for things you trust (your own code, NixOS
services). Use microVMs or VMs for things you don't trust (third-party binaries,
untrusted networks, testing destructive operations).

### 1.3 What NixOS Gives You for Free

NixOS has multiple built-in isolation systems, all declaratively configurable
through the module system. None of them require installing external tooling —
they're part of nixpkgs:

| System | Underlying tech | Isolation level | NixOS-native? |
|---|---|---|---|
| `nix develop` / `nix-shell` | Environment variables | None (not a sandbox) | ✅ Pure Nix |
| `bubblewrap` (bwrap) | User namespaces | Light (used by Nix builds) | ✅ Nix internal tooling |
| `containers.<name>` | systemd-nspawn | Namespace (light) | ✅ Full NixOS inside |
| `microvm.nix` | QEMU-microvm / Firecracker / Cloud-Hypervisor | Hardware (minimal VM) | ✅ Full NixOS inside |
| `virtualisation.vmVariant` | QEMU + KVM (full) | Hardware (full VM) | ✅ Full NixOS inside |
| `virtualisation.libvirtd` | libvirt + QEMU | Hardware (full VM) | ⚠️ Daemon only; VMs defined outside NixOS |
| `virtualisation.oci-containers` | Podman / Docker | Namespace + seccomp | ⚠️ Systemd wrapper; any OCI image — **not adopted** (decision #42) |
| `pkgs.dockerTools` | Nix-built OCI images | Build-time only | ✅ Builds images without Docker daemon |

Note: `bubblewrap` (bwrap) is used internally by Nix for build sandboxing and
by tools like `nix-alien` and `buildFHSEnv` to create read-only root filesystems
for non-Nix binaries. It's not something you'd use directly for app sandboxing,
but it's the mechanism behind Nix's own build isolation.

### 1.4 How Containers Actually Work (Linux Namespaces & Cgroups)

Containers are not virtual machines. They are standard Linux processes running
directly on the host CPU and kernel, constrained by native kernel features:

**Linux Namespaces (Visibility):**
- `pid` — Isolates the process ID space (the container's main process becomes PID 1).
- `net` — Provides an independent network stack (own routing table, IP address, nftables).
- `mnt` — Provides an isolated filesystem mount table (chroot / pivot_root).
- `ipc` — Isolates System V IPC and POSIX message queues.
- `uts` — Isolates hostname and domain name.
- `user` — Maps root UID 0 inside the container to an unprivileged UID on the host (rootless containers).

**Control Groups (cgroups v2 — Resource Allocation):**
Restricts and meters hardware utilization: CPU cores/shares, RAM hard limits,
block I/O throughput. Even if a container process tries to consume all available
memory, cgroups enforce the limit.

**Security Filters (seccomp & AppArmor/SELinux):**
- `seccomp-bpf` — Restricts system calls. Even if a process runs as UID 0 in a
  container, it cannot invoke dangerous kernel syscalls like `reboot` or modify
  kernel modules.
- AppArmor/SELinux — Mandatory access control (if configured on the host).

### 1.5 How VMs Actually Work (KVM & QEMU)

A VM boots an entirely separate operating system with its own kernel.

**KVM** (Kernel-based Virtual Machine) — a Linux kernel module (`kvm.ko`) that
turns the host kernel into a Type-1 hypervisor using CPU hardware extensions
(Intel VT-x on your T480's i5). KVM handles the CPU and memory virtualization.

**QEMU** — the userspace emulator that sets up virtual disks, virtual network
interfaces, and display adapters. QEMU passes CPU instructions directly to KVM
(no emulation overhead for CPU-bound work) but emulates I/O devices in software
(unless using virtio paravirtualized drivers).

Together: QEMU provides the virtual hardware, KVM provides the fast execution.

### 1.6 Host-Guest Interfacing & I/O

When designing sandbox configurations, communication between the host and the
isolated guest falls into four standard I/O pipelines:

```
                           HOST SYSTEM

   +-------------------+   +--------------------+   +-----------------+
   | Host Filesystem   |   | Host Network Stack |   | Host Peripheral |
   +---------+---------+   +---------+----------+   +--------+--------+
             |                       |                       |
    [Storage Interface]       [Network Interface]     [Device Interface]
    • Bind Mount (Container)  • Virtual Bridge (br0)  • Unix Sockets
    • VirtIO-FS / 9p (VM)     • NAT / TAP Adapter    • VirtIO-VSOCK
             |                       |                 • VFIO Passthrough
             v                       v                       v
   +-------------------+   +--------------------+   +-----------------+
   | Guest Filesystem  |   | Guest Network Stack|   | Guest Hardware  |
   +-------------------+   +--------------------+   +-----------------+

                   GUEST SANDBOX (Container or VM)
```

| Pipeline | Container Mechanism | VM Mechanism |
|---|---|---|
| **Filesystem sharing** | Bind mounts: host path mounted directly into container mount namespace. Zero overhead. | VirtIO-FS / 9p: host directory exposed to VM via paravirtualized file driver over shared memory. |
| **Networking** | veth pairs: virtual ethernet cable connecting container namespace to a host bridge (docker0, podman0). | TAP / Macvtap / Bridge: host creates a TAP device connected to a bridge interface, assigned IP via DHCP. |
| **Fast host-guest IPC** | UNIX domain sockets: shared socket file mounted into the container. | VirtIO-VSOCK: zero-configuration, zero-network socket protocol bypassing TCP/IP over the hypervisor boundary. |
| **Hardware access** | Device nodes exposed directly via `/dev` mounts (e.g., `/dev/dri/renderD128`). | VFIO / USB passthrough: entire PCIe lanes or USB controllers detached from host driver and bound to VM. |

### 1.7 Cross-Platform Context

This matters if you ever work across platforms:

```
LINUX (Your T480):
  Application → Linux System Calls → Host Linux Kernel (Namespaces/KVM)
  [Zero virtualization overhead for containers; direct KVM acceleration for VMs]

MACOS (Virtualization Framework):
  Container → Linux Syscalls → [Linux MicroVM (Lima/OrbStack)] → macOS XUN
  [Containers CANNOT run natively; they must run inside a Linux VM helper]

WINDOWS (WSL2 / Hyper-V):
  Container → Linux Syscalls → [WSL2 Linux Kernel VM] → Windows Hyper-V
  [Docker/Podman delegates execution to a specialized lightweight utility VM]
```

Linux (your T480): containers and KVM are native first-class kernel features.
There is zero translation layer. macOS has no Linux kernel namespaces — running
Docker on macOS spins up a hidden Linux VM behind the scenes. WSL2 is a custom
Linux kernel running inside a Hyper-V VM.

---

## 2. The Four Approaches in Detail

### 2.1 NixOS Containers (systemd-nspawn)

**What it is:** Lightweight isolation using Linux namespaces. Each container gets
its own process tree, filesystem, and (optionally) network stack — but shares the
host's kernel.

**How it works in NixOS:**

```nix
# Declare a container inside a NixOS module
containers.myService = {
  autoStart = true;
  privateNetwork = true;          # isolate network
  hostAddress = "192.168.100.1";  # host-side veth IP
  localAddress = "192.168.100.2/24";  # container-side IP

  config = { pkgs, ... }: {
    # This is a FULL NixOS config — anything you'd put in configuration.nix
    system.stateVersion = "26.05";
    boot.isNspawnContainer = true;  # required on nixpkgs 25.11+
    networking.firewall.allowedTCPPorts = [ 80 443 ];
    services.httpd.enable = true;
  };
};
```

**Key characteristics:**
- **Full NixOS inside** — the container gets its own NixOS system closure, built
  from the `config` block. You can `import` any NixOS module inside it.
- **Host-managed** — the container is rebuilt when you run `nixos-rebuild switch`
  on the host. You don't rebuild inside the container.
- **Near-zero overhead** — no hypervisor, no virtual hardware. Startup under 1 second.
- **Weak isolation** — root inside the container shares the host kernel. Not safe
  for untrusted code.

**Interacting with containers:**

```bash
nixos-container root-login myService   # enter as root
nixos-container run myService -- systemctl status  # run a command
nixos-container list                   # list all containers
nixos-container destroy myService      # tear down
```

**Networking options:**

| Mode | What happens |
|---|---|
| Shared (default) | Container uses host's network stack directly. No isolation. |
| `privateNetwork = true` | Creates a veth pair (virtual ethernet cable). Container gets its own IP. |
| `hostBridge = "br0"` | Attaches container to a bridge — multiple containers can talk to each other. |
| `interfaces = [ "eth1" ]` | Moves a physical interface *into* the container (powerful but dangerous). |
| `forwardPorts = [ "tcp:8080:80" ]` | DNAT rule: host port 8080 → container port 80. |

**Best for:** Running your own NixOS services that need process/filesystem
separation but not hardware-level isolation. Example: a web server, a build
environment, a dev sandbox.

### 2.2 QEMU VMs via `virtualisation.vmVariant`

**What it is:** A complete alternative NixOS configuration that gets compiled
into a bootable QEMU virtual machine. The VM runs its own kernel under KVM
hardware virtualization.

**How it works:**

```nix
# Inside your host's NixOS config (e.g., workstation.nix or an aspect module)
virtualisation.vmVariant = {
  # VM-specific settings (only active when building the VM)
  virtualisation = {
    memorySize = 4096;    # 4GB RAM
    cores = 4;            # 4 vCPUs
    graphics = false;     # headless (serial console)
  };

  # Full NixOS config layered on top of the host config
  # (imports from host are inherited)
  networking.hostName = "workstation-vm";
  services.openssh.enable = true;
};
```

**Building and running:**

```bash
nixos-rebuild build-vm --flake .#workstation
# Creates: result/bin/run-workstation-vm

./result/bin/run-workstation-vm   # boots the VM in QEMU
```

**How the Nix store works inside the VM:**

By default, the host's `/nix/store` is mounted into the VM via 9p (a virtual
filesystem protocol over virtio). This means:
- The VM closure is tiny — only the *differences* from the host are new store paths.
- Building the VM is fast because most paths are already on the host.
- The VM's `/nix/store` is read-only (same as the host).

If you need write access to the store inside the VM:
```nix
virtualisation.vmVariant.virtualisation.writableStore = true;
```

**Networking:**

Default is QEMU user-mode networking (SLIRP) — the VM sits behind NAT and gets
internet access automatically. Port forwarding:

```bash
QEMU_NET_OPTS="hostfwd=tcp:127.0.0.1:8080-:80" ./result/bin/run-workstation-vm
```

For bridged networking (VM appears on the physical LAN), you'd add tap interfaces
and bridge configuration — more complex but necessary for services that need to
be reachable from other machines.

**Key characteristics:**
- **Full hardware isolation** — own kernel, own boot chain, KVM boundary.
- **Ephemeral** — the VM runs from a script; disk state is lost on reboot (unless
  you configure persistent disk images).
- **Inherits host config** — the variant starts with the host's full NixOS
  configuration and layers changes on top.
- **Fast iteration** — because of the shared Nix store, building the VM after
  small config changes takes seconds, not minutes.

**Best for:** Testing NixOS configurations before deploying them to production.
Also good for sandboxing untrusted workloads with full isolation.

### 2.3 libvirtd (`virtualisation.libvirtd`)

**What it is:** An infrastructure daemon that wraps QEMU and provides a
management layer. It does NOT create VMs by itself — it provides the platform
for managing them.

**How it differs from `vmVariant`:**

| | `vmVariant` | `virtualisation.libvirtd` |
|---|---|---|
| Creates VMs? | ✅ Builds a VM derivation | ❌ Installs the daemon only |
| VM lifecycle | Ephemeral (run script) | Persistent (survives reboots) |
| VM definition | NixOS config (declarative) | XML files (imperative) |
| Management | `result/bin/run-*-vm` | `virsh` CLI, `virt-manager` GUI |
| Snapshots | No | Yes (qcow2) |
| Autostart | No | Yes (`virsh autostart`) |
| Resource mgmt | Static (memorySize/cores) | cgroups, CPU pinning, I/O throttle |

**Enabling it:**

```nix
virtualisation.libvirtd = {
  enable = true;
  qemu = {
    package = pkgs.qemu_kvm;
    swtpm.enable = true;   # TPM 2.0 emulation
  };
  allowedBridges = [ "virbr0" ];
};
```

**Then you manage VMs imperatively:**

```bash
virsh list --all                    # list VMs
virsh start myvm                    # start
virsh shutdown myvm                 # graceful shutdown
virt-install --name myvm --memory 4096 --vcpus 4 ...  # create from ISO
```

**Declarative option:** [NixVirt](https://github.com/AshleyYakeley/NixVirt)
is a separate flake that lets you define libvirt domains/networks as Nix
attribute sets. It converts them to XML and manages lifecycle. This would require
adding a new flake input.

**Best for:** Production VMs that need to persist across reboots, snapshots, and
live migration. Overkill for sandboxing/testing.

### 2.4 OCI Containers (Podman/Docker)

**What it is:** A NixOS module (`virtualisation.oci-containers`) that generates
systemd services running `podman run` or `docker run` commands.

```nix
virtualisation.oci-containers = {
  backend = "podman";  # or "docker"

  containers.nginx = {
    image = "docker.io/library/nginx:latest";
    autoStart = true;
    ports = [ "8080:80" ];
    volumes = [ "/var/www:/usr/share/nginx/html:ro" ];
  };
};
```

**Key differences from NixOS containers:**

| | NixOS containers (nspawn) | OCI containers (Podman) |
|---|---|---|
| Inside the container | Full NixOS (nixos-rebuild) | Any Linux distro (from image) |
| Image source | NixOS config → system closure | OCI registry (Docker Hub, etc.) |
| Isolation | Namespaces only | Namespaces + seccomp + capabilities |
| Security | Weaker (root shares kernel) | Stronger (seccomp blocks syscalls) |
| NixOS-native | ✅ | ⚠️ Systemd wrapper around external tool |

**Decision: NOT adopted.** See decision #42 in `decisions.md`. User has no
Docker/Podman experience; server architecture uses native `services.*` modules;
`pkgs.dockerTools` covers the OCI image edge case without runtime Podman.

**Why not:** The user has never used Docker/Podman and specifically asked about
*native Nix VMs*. The server architecture plan settled on native `services.*`
modules. OCI containers require learning a separate ecosystem (image registries,
Dockerfiles, volume management) that exists outside the Nix module system. If an
OCI image is ever needed, `pkgs.dockerTools` builds it from a Nix derivation
without requiring Podman/Docker at runtime.

### 2.5 Nix-Specific Sandboxing Paradigms (Additional)

Beyond the four main module-based approaches, NixOS has several other isolation
tools worth knowing about:

**Paradigm: `nix develop` / `nix-shell` — Build & Development Isolation**

Pure environment-variable isolation. Creates an ephemeral shell with precisely
pinned compilers and dependencies in `$PATH` and `$LD_LIBRARY_PATH`. This is what
you use for `nix build` and `nix develop` already. Not a security boundary — the
process shares your user, filesystem, network, and process tree entirely.

**Paradigm: `bubblewrap` (bwrap) — Lightweight Unprivileged Sandboxing**

A CLI tool that leverages unprivileged Linux user namespaces to construct
ephemeral, read-only root filesystems on the fly. Nix uses it internally for
build sandboxing, and tools like `nix-alien` and `buildFHSEnv` use it to create
FHS-compatible environments for non-Nix binaries (tricking them into seeing
standard `/lib64`, `/usr/bin` paths). Not something you'd use directly for app
sandboxing, but it's the mechanism behind Nix's own build isolation.

**Paradigm: `microvm.nix` — Declarative MicroVMs**

A specialized NixOS framework that compiles a NixOS configuration directly into a
hypervisor microVM using Cloud-Hypervisor, QEMU-microvm, or Firecracker. Gives
you the speed and low RAM overhead of a container (~50-128MB RAM, <500ms boot)
with the complete security isolation of a separate Linux kernel. Requires adding
the `microvm.nix` flake input. Worth evaluating if vmVariant proves too heavy for
frequent sandbox use.

**Paradigm: `pkgs.dockerTools` — OCI Images Built with Nix**

Generates bit-for-bit reproducible Docker/OCI image tarballs directly from Nix
derivations without running the Docker daemon. Images contain only the explicit
closure of your application (no leftover package manager caches, bash shells, or
rootfs bloat), often resulting in images under 20MB. Useful if you ever need to
produce container images for others to run, without adopting Docker yourself.

### 2.6 Comparison Matrix

| Approach | Isolation Level | Boot Latency | RAM Overhead | Defined Via | Best Used For |
|---|---|---|---|---|---|
| `nix develop` | Environment vars | Instant | 0 MB | `flake.nix` | Pinned dev toolchains |
| `bubblewrap` (FHS) | Linux namespaces | <10 ms | Negligible | Nix derivation | Running unpatched pre-compiled binaries |
| `nixos-container` | Namespaces + cgroups | ~500 ms | ~15-30 MB | NixOS module | Isolated background services |
| Podman / Docker | Namespaces + seccomp | ~1 sec | ~30-50 MB | OCI / Compose | Multi-container apps (Nextcloud, Pi-hole) — **not adopted** (decision #42) |
| `microvm.nix` | Hypervisor (minimal VM) | <500 ms | ~64-128 MB | Nix flake / module | Untrusted builds, isolated network routing |
| QEMU / KVM (libvirtd) | Hypervisor (full VM) | 5-15 sec | >512 MB | libvirtd XML / NixVirt | Production VMs, snapshots, migration |
| `vmVariant` (NixOS) | Hypervisor (full VM) | 5-15 sec | >512 MB | NixOS module | Testing configs, sandboxing, review |

---

## 3. Recommendation: What to Build

### 3.1 The Approach

Build a **`nixos.vmVariant` aspect module** as the primary sandboxing tool.
Optionally, build a **`nixos.nixosContainer` aspect** for lightweight cases.

**Rationale:**

- `vmVariant` gives full hardware isolation with a NixOS-native workflow. No
  external tooling, no Dockerfiles, no image registries. Everything is a Nix
  module.
- It shares the host's Nix store (fast builds, no disk waste).
- It inherits the host config (no duplication).
- It works on both workstation and server.
- It's the natural fit for the dendritic architecture: one aspect module
  controls VM settings, hosts pick it up like any other aspect.

### 3.2 What the Module Would Own

A new file: `modules/virtualisation/vm-sandbox.nix`

**System scope (`nixos.vmSandbox`):**
- `virtualisation.vmVariant` — default VM settings (memory, cores, graphics,
  networking)
- Shared directory configuration for host↔VM file exchange
- Port forwarding defaults

**The module does NOT:**
- Define specific VMs (that's the host's job via inline overrides)
- Enable libvirtd (separate concern, defer to server needs)
- Define containers (separate aspect if needed later)

### 3.3 Host Integration Pattern

```nix
# modules/hosts/workstation.nix (addition)
self.modules.nixos.vmSandbox   # import the aspect

# Then, host-specific overrides inline:
({ lib, ... }: {
  virtualisation.vmVariant = {
    virtualisation.memorySize = lib.mkForce 8192;
    virtualisation.cores = lib.mkForce 4;
    virtualisation.graphics = lib.mkForce false;
    # Add sandbox-specific services:
    services.openssh.enable = true;
  };
})
```

```nix
# modules/hosts/server.nix (addition)
self.modules.nixos.vmSandbox   # same aspect, different host

# Server might override:
({ lib, ... }: {
  virtualisation.vmVariant = {
    virtualisation.memorySize = lib.mkForce 2048;
    virtualisation.cores = lib.mkForce 2;
    virtualisation.graphics = lib.mkForce false;
  };
})
```

### 3.4 Build & Run Workflow

After importing the aspect, any host can build and run a sandboxed VM:

```bash
# Build the VM
nixos-rebuild build-vm --flake .#workstation

# Run it
./result/bin/run-workstation-vm

# Or build without switching (dry eval)
nix build .#nixosConfigurations.workstation.config.system.build.vm --dry-run
```

### 3.5 What About the Server's Gateway VM?

The server architecture plan (`server-architecture-decisions.md`) rejected
VM-based routing due to IOMMU limitations. The `vmSandbox` aspect is for
*sandboxing* (isolating untrusted workloads), not for replacing the server's
routing stack. These are different concerns:

| Concern | Approach |
|---|---|
| Sandboxing apps/services on workstation | `vmSandbox` aspect (vmVariant) |
| Server routing/gateway | Native NixOS (nftables + dnsmasq) — already settled |
| Server persistent VMs (future) | libvirtd — defer until needed |

---

## 4. Open Questions

1. **Shared directories:** What host paths should be shared into the VM by
   default? The nix store is automatic. Beyond that — home directory? Project
   directories? Nothing (air-gapped sandbox)?

2. **Networking mode:** Default to QEMU user-mode (NAT, simple, no host config
   needed) or bridged (VM appears on LAN, needs bridge setup)? User-mode is
   safer for sandboxing; bridged is needed if the VM runs services reachable
   from other machines.

3. **NixOS containers as a second aspect:** Should we also build a
   `nixos.nixosContainer` aspect for lightweight sandboxing (no KVM overhead),
   or is vmVariant sufficient for all use cases?

4. **Persistent vs ephemeral:** Should the VM disk persist across reboots
   (useful for dev environments) or stay ephemeral (true sandbox, state
   discarded on shutdown)? The default vmVariant is ephemeral.

5. **microvm.nix evaluation:** Should we evaluate `microvm.nix` as an
   alternative to `vmVariant` for sandboxing? It offers VM-grade isolation with
   near-container startup times (~500ms boot, ~64-128MB RAM) but requires a
   separate flake input and has less flexibility than full VMs.

6. **KVM availability:** Confirmed — `/dev/kvm` is present and `kvm-intel` is
   in `boot.kernelModules` (from `hardware-t480.nix`). VM acceleration is
   ready to use.
