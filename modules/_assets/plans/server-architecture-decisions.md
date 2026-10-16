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
* **Status:** **Superseded by §2.9/§2.10** — the hardware migration this was deferred until is now actually happening (new laptop incoming), just in the opposite direction than imagined here: it's the *workstation* that gets new hardware, not the server. The T480 keeps `nixos.hardwareConfig` unchanged, permanently, under its new server role. Kept for history; see §2.9 for the current plan.

### 2.6. Secrets Management
* **Decision:** Introduce `sops-nix` as a flake input. Create a `nixos.sops` base aspect.
* **Justification:** WireGuard keys, Nextcloud credentials, and database passwords require encryption at rest. `sops-nix` integrates with `nixpkgs` systemd service definitions, injecting secrets via `LoadCredential`.
* **Status:** Settled.

### 2.7. Hardware Swappability
* **Decision:** Keep `server.nix` as a thin entry point importing `nixos.server`, `nixos.base`, and `nixos.hardwareConfig`.
* **Justification:** Decouples hardware constraints (disk UUIDs, kernel modules) from software topology. Future migration to a dedicated target requires writing a new `nixos.hardware-<newTarget>` aspect and updating a single import line in `server.nix`.
* **Status:** Settled.

### 2.8. SSH Second-Factor Authentication
* **Decision:** Add `security.pam.services.sshd.googleAuthenticator.enable = true;` (plus `AuthenticationMethods = "publickey,keyboard-interactive";` in the server's `services.openssh.settings`) when this host goes live. Google Authenticator TOTP, not Duo or privacyIDEA.
* **Justification:** Already implemented and verified on the work-desktop host (a standalone-HM machine with no Nix authority over PAM, so that one required a manual runbook) — see `completed/2fa-select-hosts-research.md`. Chosen there for zero cost, zero third-party account, and zero external service in the auth path; the server host inherits the same reasoning but gets to be fully declarative since it's NixOS. This is a genuinely native nixpkgs option (`security.pam.services.<name>.googleAuthenticator`, backed by `pkgs.google-authenticator-libpam`), not a hand-rolled PAM rule.
* **Carry over from the work-desktop rollout, applies here too:** check whether Tailscale SSH (`tailscale up --ssh`) is active on this host before assuming the PAM/`sshd_config` change takes effect — it silently intercepts port 22 over the tailnet interface and supersedes the real `sshd` entirely if enabled, which is what actually blocked the work-desktop rollout at first. Verify with `ssh -v <host> true 2>&1 | grep "remote software version"` — `OpenSSH_...` confirms you're reaching the real daemon.
* **Verified:** `security.pam.services.<name>.googleAuthenticator.enable` and `pkgs.google-authenticator-libpam` both confirmed present against the pinned nixpkgs release-26.05 source.
* **Status:** Deferred — not implemented, no server host exists yet. Revisit alongside `nixos.security`/`nixos.network` when `server.nix` is actually built (§2.2, §3). **Reinforced, not just left pending, by §2.11's "streamlined SSH, reduced latency between hosts" goal** — a TOTP prompt is exactly the human-interaction latency that goal argues against. `host.require2fa` stays `false` on the server for now; the scaffolding is a one-line flip whenever actually wanted.

### 2.9. Role Swap — New Workstation Hardware, T480 Becomes Server
* **Decision:** A new laptop replaces the T480 as the daily-driver `workstation`. The T480 becomes the permanent `server`: always on, docked at a KVM, no longer dual-purposed with `workstation`/`laptop`.
* **Justification:** `workstation.nix` and `laptop.nix` are both currently configs for the *same* physical T480 (`host.hostName = "t480-nixos"` in both — see decision #59/§2.10 below). That symmetry was always provisional, built to diverge "once the Framework 13/server split happens" (the exact language used when `host.hostName` was first promoted to an option). This is that split.
* **What doesn't change:** `laptop.nix` stays as an available alt-boot config for the T480's hardware — it was never part of this swap and isn't being retired.
* **What does:** `server.nix` (currently a one-line stub) becomes the T480's primary, actually-deployed config, inheriting the T480's existing `nixos.hardwareConfig`, `host.hostName = "t480-nixos"`, and the `host.trustedSshKeys` list currently sitting in `workstation.nix`. The *new* `workstation.nix` needs a brand-new hardware module (`nixos.hardware-<model>`, same wrapping pattern as `hardware-t480.nix` — see #7 in `decisions.md`) and a fresh `host.hostName` + its own SSH keypair, generated and registered the same way the work desktop and iPhone already are — `host.trustedSshKeys`'s existing design needs no new mechanism, just new values once the new laptop's own hardware-configuration.nix can actually be generated (can't happen until the hardware is in hand).
* **Status:** Planned — execute per §7's bring-up checklist. `server.nix` can be fleshed out and deployed on the T480 before the new laptop even arrives, since none of it depends on the new hardware.

### 2.10. Host Identity Migration
* **Decision:** `host.hostName`/`host.trustedSshKeys` move with the T480's *role*, not its old host-file name — `server.nix` inherits both values currently in `workstation.nix`/`laptop.nix` verbatim (same hostname, same trusted devices: work desktop, iPhone). The new `workstation.nix` starts with an empty `trustedSshKeys` (nothing needs to SSH *into* a daily-driver laptop by default) and a new hostname reflecting the actual new hardware, not reusing "t480-nixos."
* **Justification:** This is exactly the scenario `host.hostName`'s no-default design was built to force a conscious choice about (decision #59) — an unset or accidentally-reused hostname across genuinely distinct physical machines would collide in Tailscale's device list, SSH `known_hosts`, and nftables logs. Carrying the T480's identity to `server.nix` rather than letting it lapse keeps `known_hosts` entries, existing trust relationships, and Tailscale ACLs that reference "t480-nixos" all correct without any cleanup on the other hosts' side.
* **Status:** Planned — see §7.

### 2.11. TTY-Only Server — No Desktop Stack
* **Decision:** `server.nix` imports no desktop aspect at all — not `nixos.desktop`, not `homeManager.desktop`, no Hyprland/Noctalia, no display manager. The box boots to a plain text console.
* **Justification:** This was reconsidered mid-planning from an earlier "same desktop as workstation" direction. A desktop-capable server is architecturally just "a laptop hosting a few services" — barely distinguishable from the workstation, and a desktop session on it would rarely actually get used. TTY-only makes the server's identity distinct from day one: a service host reached through each service's own web UI (Jellyfin, Nextcloud — see §6) or over SSH, not through sitting down at the KVM and opening a graphical session. This also directly serves the "streamlined SSH, reduced latency between hosts" goal — no desktop compositor competing for resources, nothing to keep resident just in case someone's physically present.
* **Mechanical note:** "headless until the KVM gives input" needs no special module either way — a NixOS host with no display manager configured already boots straight to a kernel framebuffer text console on whatever's attached. The one piece of existing infrastructure that still matters here is `services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore"` (already in `network.nix`) — it's the thing actually preventing the box from suspending when the lid's closed and nobody's at the KVM.
* **Status:** Settled.

### 2.12. Battery Management Reconsidered for a Permanently-Docked Server
* **Decision:** `server.nix` imports `nixos.battery` individually (not bundled via `nixos.base`, consistent with §3's existing exclusion of that group for servers) — reversing the original "laptop-only, exclude from server" framing in §3 for this one aspect specifically.
* **Justification:** §3's exclusion reasoning was written when "server hardware" was still an open question — it might not even have been a laptop. Now that the server is definitely the T480, a real laptop kept permanently plugged in at a KVM, TLP's charge-threshold management becomes *more* relevant than on a normal laptop, not less: holding a lithium cell pinned at 100% charge 24/7 degrades it measurably over the server's expected multi-year uptime. `nixos.audio` stays excluded — more clearly correct than before now that there's no desktop session to produce sound for at all.
* **Status:** Settled.

## 3. `nixos.base` Group Scope Audit

**Problem identified:** `nixos.base` currently bundles `nixos.battery` and `nixos.audio`:
* `nixos.battery` (TLP, dual-battery charge thresholds, CPU governor) — originally flagged laptop-only here; **reversed in §2.12** once the server's hardware was settled as a permanently-plugged-in T480, where charge-threshold management actually matters more, not less. Import individually, same as the rest of this list — just don't pull in the whole `nixos.base` bundle for it.
* `nixos.audio` (PipeWire) — desktop-only; stays excluded, now even more clearly correct given §2.11's TTY-only decision (no desktop session exists to produce sound for).

**Decision:** `server.nix` should **not** import `nixos.base`. Instead, import the individual headless-safe aspects directly:
* `nixos.network` — Networking, firewall, Tailscale, SSH. Also where `AuthenticationMethods` for the §2.8 2FA decision lands.
* `nixos.hardware` — fstrim, fwupd, earlyoom (generic, no laptop assumptions).
* `nixos.security` — Kernel sysctl hardening, PAM faillock lockout, and (per §2.8) Google Authenticator TOTP for SSH.
* `nixos.battery` — per §2.12, individually, not as part of a bundle.

**Future option:** Create a `nixos.serverBase` group aggregating these four, plus any server-specific additions (see §4). This keeps the host file clean while avoiding polluting the existing `nixos.base` group with conditionals.

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

**Correction:** On the same physical T480, the root filesystem IS ext4 — the existing `nixos.hardwareConfig` already declares `fileSystems."/" = { fsType = "ext4"; ... }`. There is no separate partition layout to model. A second hardware profile would duplicate identical `fileSystems` entries for no benefit. Deferred to hardware migration (§2.5) — **resolved by §2.9**: the T480 keeps this exact hardware module permanently as the server; no second profile is ever needed for it. The hardware migration that *does* need a new profile is the new workstation laptop, tracked in §7.

## 6. Service & Future Feature Staging

The server now has a defined purpose — a service host reached by SSH or by
each service's own web UI (§2.11) — rather than an open-ended "add things
later" box. Staging splits into what the server is actually *for*, and what
stays genuinely deferred.

### 6.1. Near-term target: the services this box exists to run
* **Jellyfin** (`services.jellyfin.enable`) — owned media. Native NixOS
  module, not a container — same "avoid OCI black boxes" reasoning as
  §2.3's Nextcloud/AdGuard choices.
* **Nextcloud-style file cloud** (`services.nextcloud`) — already verified
  present in §2.3's option-path check. Not re-verified here; same module.
* Both land in the `nixos.server` aspect group from §2.3 once implemented.
  **Not implemented this round** — "get online first" (identity, SSH,
  networking) still comes before services; named here so the aspect group
  being built now is shaped around its actual intended tenants, not left
  generic.

### 6.2. Still genuinely deferred
* **AdGuard Home / pihole-equivalent** — `services.adguardhome`, already
  verified present (§2.3). No change to that finding; still not in scope.
* **WiFi AP routing** — not previously researched. `services.hostapd` is
  the native NixOS option for turning a WiFi interface into an access
  point; would pair with the existing `networking.nftables`/`dnsmasq`
  router stack from §2.2. Needs its own verification pass against the
  T480's specific WiFi chipset before treating this as settled — noted as
  the likely mechanism, not confirmed working.
* **External hard drives** — no architecture change needed: new disks are
  additional `fileSystems."/mnt/<name>"` entries in `nixos.hardwareConfig`
  (or a sibling module), added incrementally as drives are physically
  attached. This is exactly the kind of "slot in without overhaul" case
  the hardware-module split (§2.9) is designed to absorb.
* **eGPU** — needs its own re-evaluation *at the time*, not an inherited
  conclusion from §1. §1's PCIe/Thunderbolt-passthrough constraints were
  evaluated specifically for passthrough *into a VM* — a Thunderbolt eGPU
  used directly at the host level (no VM involved) is a materially
  different risk profile and isn't ruled out by today's findings either
  way. Flagged as unresearched, not rejected.

### 6.3. "Streamlined SSH, reduced latency between hosts"
The existing `host.trustedSshKeys` pubkey-only path (decision #59) is
already minimal-overhead for host-to-host access — no password or 2FA
round-trip, consistent with §2.8's deferral being reinforced rather than
just left pending. If connection-*setup* latency (not the data path) ever
becomes the actual bottleneck for repeated calls between hosts, SSH's
`ControlMaster`/`ControlPersist` multiplexing (reusing one authenticated
connection instead of renegotiating per command) is the natural next
lever — noted here as available, not applied anywhere in this repo yet.

## 7. Bring-Up Checklist

The actual sequence for executing §2.9-§2.12, in order. Steps 1-2 need the
new laptop physically in hand; steps 3-6 don't and can happen first.

1. **Generate the new laptop's hardware config**: `sudo nixos-generate-config`
   on the new hardware, port the result into a new
   `modules/system/hardware-<model>.nix` → `nixos.hardware-<model>`
   registry module (same wrapping pattern as `hardware-t480.nix` — bare
   NixOS modules can't live loose under `modules/`, see decisions.md #7).
2. **Pick the new workstation's identity**: a new `host.hostName` (not
   reusing "t480-nixos"), generate a new SSH keypair on the new laptop,
   register its public key as a new GitHub identity (matching the existing
   per-device-keypair convention), and add it to whichever hosts the new
   laptop needs to reach (`work.nix`'s `host.trustedSshKeys`, and the
   server's, if the new laptop should be able to SSH into the T480).
3. **Flesh out `server.nix`** (currently a one-line stub): the T480's
   existing `nixos.hardwareConfig`, `host.hostName = "t480-nixos"`, the
   `host.trustedSshKeys` list currently in `workstation.nix`, the
   `nixos.{network,hardware,security,battery}` singles (not `nixos.base`,
   per §3/§2.12) plus `nixos.sandbox`, and `nixos.main` with §4's
   `lib.mkForce` overrides (`flatpak`, `fonts.packages`). No desktop
   aspect at all, per §2.11.
4. **Deploy `server.nix` on the T480** — can happen immediately, before
   step 1/2 are even possible, since nothing about it depends on the new
   hardware.
5. **Rewrite `workstation.nix`** once step 1-2 are done: point at the new
   hardware module and identity; `laptop.nix` is untouched throughout
   (still the T480's alt-boot config, per §2.9).
6. **Deploy the new `workstation.nix`** on the new laptop.
7. Confirm SSH into the T480 (now "server") still works from every
   currently-trusted device, since `host.trustedSshKeys` carried over
   verbatim in step 3 — this should be a non-event if step 3 was done
   correctly, worth confirming rather than assuming.
