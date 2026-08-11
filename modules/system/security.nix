# nixos.security — Nix settings, GC & kernel hardening (system scale).
#
# Template for leaning out modules/configuration.nix (nixos.main).
# Planned content (currently in nixos.main):
#   - nix.settings (experimental-features, auto-optimise-store, sandbox)
#   - nix.gc (weekly, --delete-older-than 14d)
#   - boot.kernel.sysctl hardening (rp_filter, kptr_restrict, bpf_jit_harden,
#     accept_redirects, send_redirects, accept_source_route)
#
# NOT wired into any host until populated.
{ inputs, ... }: {
  flake.modules.nixos.security = { ... }: { };
}
