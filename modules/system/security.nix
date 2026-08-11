# nixos.security — Kernel hardening (system scale).
#
# Leaned out of modules/configuration.nix (nixos.main).
# NOTE: nix.settings / nix.gc intentionally stay in nixos.main (user choice).
# Wired into workstation.nix via `self.modules.nixos.security`.
{ inputs, ... }: {
  flake.modules.nixos.security = { ... }: {
    # Kernel sysctl hardening
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;
      "kernel.kptr_restrict" = 2;
      "net.core.bpf_jit_harden" = 2;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv6.conf.all.accept_source_route" = 0;
      "net.ipv6.conf.default.accept_source_route" = 0;
    };
  };
}
