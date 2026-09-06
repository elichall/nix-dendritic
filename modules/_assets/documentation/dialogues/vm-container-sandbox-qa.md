# VM / Container / Sandbox — Conceptual Q&A

Conceptual Q&A session on minimal VM and container topics: agent process
sandboxing, GPU-bound OCI deployment, and embedded-system isolation. No code
changes came out of this — captured here as reference for when any of these
actually get built. Related reading: [[agent_sandbox_plan]],
[[NIX_PHILOSOPHY]], [[server-architecture-decisions]].

---

## 1. Directory-scoped sandbox for `opencode`/`claude` — only down, never up

Not hypothetical — [[agent_sandbox_plan]] already specs this in this repo.
The mechanism is Linux mount namespaces via `bubblewrap` (`bwrap`), and the
"down always visible, up never" property falls out of how bind-mount
namespaces work, not from an access-control rule you write:

- `bwrap` builds the sandboxed process's filesystem view **from nothing** —
  any path not explicitly bound doesn't exist in that process's view
  (`ENOENT`, not "permission denied").
- Bind `$PWD` read-write at its own path. Binding a directory recursively
  includes everything beneath it, so "see everything down" needs zero extra
  work.
- The parent directories leading up to that bind point (e.g. `/home`,
  `/home/you`, if cwd is `/home/you/project`) must exist as empty stub
  directories purely so the path resolves — "traveling up" doesn't error,
  it just finds nothing there. Structurally present, functionally inert.
  That's "never travel up," for free.
- Also bind `/nix/store` read-only (the tools' runtime deps live there),
  `/proc`, `/dev`, `/etc/resolv.conf` for DNS. `--share-net` for outbound
  API calls — full network isolation is possible but adds complexity for no
  benefit here, since the thing being isolated is the filesystem, not the
  network.

The wrapper is a `writeShellScriptBin` computing `$PWD` at invocation time,
`exec`ing `bwrap ... -- opencode "$@"` (or `claude`), installed on `PATH`
ahead of the real binary via `home.packages`. [[agent_sandbox_plan]] already
has a working `flake.nix` skeleton for this — close to done, never actually
wired into a host.

---

## 2. GPU-bound research simulation → OCI image, no Nix required to run

Two things get conflated in "GPU passthrough," worth separating:

**Plain GPU compute access** needs the NVIDIA Container Toolkit (or ROCm's
equivalent), which injects `/dev/nvidia*` device nodes and *userspace*
driver libraries into the container at **launch time** — a runtime concern,
not baked into the image. The image just needs CUDA userspace runtime libs
(`cudaPackages.cuda_cudart`, not the whole toolkit) at a version the host
driver supports via NVIDIA's forward-compatibility guarantee. The kernel
driver itself never lives in the container — it can't; kernel modules
aren't containerizable.

**GPUDirect Storage** (NVMe→GPU-memory DMA bypassing the CPU) is a harder
ask: needs the `nvidia-fs` kernel module **on the host**, a compatible
storage topology (local NVMe behaves very differently from network
storage), and `libcufile` in userspace matching. Genuinely host-dependent in
a way containers can't fully abstract — the container needs
`/dev/nvidia-fs*` passed through and often `--privileged`, and whether GDS
actually engages (vs. silently falling back to a slower CPU bounce-buffer
path) depends on host kernel/storage specifics outside the container's
control.

**Container type**: a minimal OCI image via `pkgs.dockerTools.buildLayeredImage`
— just the compiled binary + minimal CUDA runtime shared libs, no
toolchain, no devShell bloat. This is Layer 2 in [[NIX_PHILOSOPHY]]: Nix
builds the artifact, the OCI format handles distribution. Worth knowing for
a research-lab context specifically: **Apptainer/Singularity, not Docker,
is the actual standard on GPU HPC clusters** (no root daemon, integrates
with SLURM-managed multi-tenant nodes) — a Nix-built OCI image is directly
consumable by Apptainer too (`apptainer run docker-archive:image.tar`), so
building it the Nix way doesn't lock into Docker.

---

## 3. Pure max performance, any Linux+GPU — container or not?

Container, and not close — for a reason that isn't obvious at first: **a
bare Nix-built binary fundamentally cannot satisfy "any Linux system, no
Nix required" at all.** Nix binaries are dynamically linked against an
exact `/nix/store` closure — the dynamic linker path is hardcoded to
something like `/nix/store/<hash>-glibc/lib/ld-linux.so`. Copy that binary
to a machine without the Nix store present and it doesn't run — there's no
"mostly works," it fails to load outright. Static linking against CUDA is
impractical. So this isn't really "container vs. bare binary," it's
"container vs. something that doesn't work at all" given the stated
constraint.

On overhead: **containerized GPU compute runs at native speed for the
actual kernel-launch/compute path** — containers are namespace+cgroup
isolation on the *same* kernel, not a hypervisor, so there's no
virtualization tax the way there is with VM-based GPU passthrough (already
flagged as structurally rough on the T480 in
[[server-architecture-decisions]] — PCIe/IOMMU group constraints). The
overhead that does exist (container startup, a filesystem-indirection
syscall or two) is a rounding error against an hours-long simulation run.
The one place real overhead can show up is GDS/RDMA-sensitive paths across
a container's network/storage namespace — mitigated with `--net=host` and
binding the raw data path directly rather than through an overlay
filesystem layer, not by avoiding containers.

Containerize (OCI/SIF via `dockerTools`, run via Apptainer for the `--nv`
flag and cluster-native GPU handling) — not "overhead worth paying," but
the only mechanism that actually satisfies the portability constraint as
stated.

---

## 4. Sandboxing an ESP32 inverted-pendulum stabilization rig (3 motor drivers, IMU, encoders, mux)

A genuinely different problem class from §1-3, worth being explicit about
why: everything above was OS-level sandboxing (namespaces, mount
isolation) — the ESP32 doesn't run Linux, has no processes in that sense,
and (on most variants) no MMU providing hardware memory protection between
tasks. `bwrap`-style sandboxing has no meaning here — there's no kernel
underneath providing the isolation primitives it relies on. "Sandboxing"
for this system splits into two genuinely different concerns:

**Hermetic build toolchain** (the one Nix actually helps with) —
[[NIX_PHILOSOPHY]] already anticipates this exact case under Layer 1
("embedded microcontroller toolchains... C++/PlatformIO for LQR reaction
wheels"). The value isn't runtime isolation, it's making sure
`idf.py build`/`platformio run` produces the same firmware regardless of
whose machine runs it. ESP-IDF resists clean Nix packaging the same way
CUDA does — its own `install.sh`/`export.sh` wants to manage its own
toolchain download — so the pragmatic move is the same pattern as the ML
case in [[NIX_PHILOSOPHY]]: a `buildFHSEnv` wrapping ESP-IDF's own
installer rather than re-deriving the whole toolchain as pure Nix
derivations. `modules/system/sandbox.nix` already has scoped-devShell
plumbing precedent for this kind of thing.

**Runtime fault containment** (the actual safety question for a physical
rig) — a 3-motor stabilization rig has real physical-harm/hardware-damage
stakes if a task hangs, and *software* isolation can't fully cover that on
hardware without an MMU. Real analogs, in order of how much isolation they
actually buy:
- **FreeRTOS task separation** — IMU read, encoder read, motor PID, and a
  dedicated safety-monitor as separate tasks with distinct
  priorities/stacks. Cooperative, not a hard boundary — a buggy task can
  still stomp shared memory without careful mutex/queue discipline.
- **FreeRTOS-MPU** (MPU-capable variants only — S3/C3, not the plain
  original ESP32) gives actual hardware-enforced restricted memory regions
  per task — the closest real analog to OS-level sandboxing this hardware
  family offers.
- **The boundary that actually matters is hardware, not software**: a
  watchdog timer cutting motor power if the control loop stalls,
  current-limiting on the drivers, a physical e-stop independent of the
  MCU. No amount of software sandboxing substitutes for this layer.

---

## 5. Is machine-specific compile-and-mail-back normal for high-performance sim code?

Half right as "poor env management," half a real HPC practice. Breaking
down why vendors actually do this:

**Legitimate, still-common-in-HPC reasons:**
- **CPU microarchitecture targeting** (`-march=native`/`-march=skylake-avx512`)
  — exact ISA extensions (AVX-512, FMA, cache-tuned codegen) can matter
  20-40%+ for vectorizable kernels vs. a generic baseline build. Real
  enough that **Spack** and **EasyBuild** (the two dominant HPC package
  managers) exist specifically to automate "rebuild per target machine" as
  normal engineering, not a smell.
- **GPU compute-capability targeting** (`nvcc -arch=sm_80` vs `sm_90`) —
  ahead-of-time SASS for the exact GPU avoids PTX JIT startup cost; fat
  binaries embedding multiple `-gencode` targets are possible but bloat
  size, so vendors often skip it.
- **Interconnect-specific builds** — MPI over InfiniBand/Slingshot/etc.
  genuinely needs linking against the exact on-node network stack; a
  generic binary can silently fall back to slow TCP instead of the fast
  fabric. Not "same binary, slightly slower" — can be "the fast path
  literally isn't available."

**The part that's actually weaker engineering (or something else):** the
round-trip to the *vendor* specifically, rather than building locally from
source with a provided script, has no strong performance justification
once the source is already available. Modern well-engineered
high-performance libraries solve "right variant per machine" without a
mail-back cycle: runtime CPU dispatch (OpenBLAS/MKL pick the ISA-optimal
path at runtime), FFTW's "wisdom" system, or just running Spack/the build
script locally. The mail-back pattern is more typical of **closed-source
commercial vendors** who can't hand over a source tree, or — more
cynically — sometimes partly a **license-enforcement mechanism** (binary
node-locked to a machine fingerprint) dressed up as optimization. For an
in-house rewrite that owns its own source, there's no reason to inherit
that workflow.

**Connects back to §3's Nix framing**: `-march=native` builds are in real
tension with Nix's reproducibility/binary-cache model — a native-tuned
build isn't cacheable across different CPUs by definition. The clean
answer: ship a portable baseline build through the normal Nix/cache path
for reproducibility, and offer a `nix build --option ... -march=native`-style
local override for users who want the tuned version built *on their own
machine* — no vendor round-trip needed, since the source and build recipe
are already in hand.
