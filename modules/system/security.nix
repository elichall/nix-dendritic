# nixos.security — Kernel hardening (system scale).
#
# Leaned out of modules/configuration.nix (nixos.main).
# NOTE: nix.settings / nix.gc intentionally stay in nixos.main (user choice).
# Wired into workstation.nix via `self.modules.nixos.security`.
{ inputs, ... }: {
  flake.modules.nixos.security = { config, ... }: {
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

      # Defense-in-depth additions:
      "kernel.yama.ptrace_scope" = 1; # a process may only ptrace its own children
      "kernel.dmesg_restrict" = 1; # unprivileged users can't read kernel pointer leaks in dmesg
      "net.ipv4.tcp_syncookies" = 1; # SYN-flood resistance (usually kernel-default, pinned explicitly)
      "fs.protected_hardlinks" = 1; # can't hardlink to files you don't own
      "fs.protected_symlinks" = 1; # closes symlink-following privesc in world-writable dirs
    };

    # Lock local (console/sudo) and SSH auth out after repeated failures.
    # NOTE: security.pam.services.<name>.rules is upstream-flagged
    # experimental ("subject to breaking changes without notice") — re-check
    # this block against the pinned nixpkgs's nixos/modules/security/pam.nix
    # after any nixpkgs bump. modulePath is intentionally left unset here:
    # `logFailures = true` turns on nixpkgs' own built-in faillock rule,
    # which already resolves the module path from config.security.pam.package
    # — no path needs to be hardcoded.
    security.pam.services = {
      login = {
        logFailures = true;
        rules.auth.faillock.settings = {
          deny = 5;
          unlock_time = 900;
        };
      };
      sudo = {
        logFailures = true;
        rules.auth.faillock.settings = {
          deny = 5;
          unlock_time = 900;
        };
      };
      sshd = {
        logFailures = true;
        rules.auth.faillock.settings = {
          deny = 5;
          unlock_time = 900;
        };
        # Scaffolding for host.require2fa (modules/options/hostOpt.nix) —
        # off by default (bool binds straight through, no mkIf needed).
        # Verified working on the work desktop's manual (non-Nix) runbook;
        # see 2fa-select-hosts-research.md §9 for the declarative version.
        googleAuthenticator.enable = config.host.require2fa;
      };
    };
  };
}
