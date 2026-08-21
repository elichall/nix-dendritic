# Skill: Nix Option Domain Classification

## Purpose
Classify top-level attrset keys from legacy files in `./nixos/` into either `flake.modules.nixos.<feature>` or `flake.modules.homeManager.<feature>`.

## Authority
The current registry (every key → file/scope/ownership) is the source of truth:
`modules/_assets/documentation/module-contracts.md` §1. Rationale behind the classifications:
`modules/_assets/documentation/decisions.md` (esp. decisions 3, 8, 10). Always prefer those
over memorizing this table — the table below is the general rule.

## Domain Mapping Rules

| Key Pattern | Target Domain | Reason |
| :--- | :--- | :--- |
| `boot.*`, `hardware.*`, `fileSystems.*`, `swapDevices.*` | `nixos` | System kernel and low-level storage |
| `services.*` (e.g., `services.openssh`, `services.xserver`) | `nixos` | System-wide Daemons / Systemd system services |
| `environment.systemPackages` | `nixos` | Binaries exposed in `/run/current-system/sw/bin` |
| `users.users.*` | `nixos` | System POSIX user/group declarations |
| `programs.<name>.enable` (System tools: `dconf`, `gnupg`, `bash`) | `nixos` | System security wrappers and global PAM integration |
| `programs.<name>.*` (Dotfiles: `starship`, `git`, `neovim`, `tmux`) | `homeManager` | User-space configuration and state |
| `home.packages`, `home.file`, `home.sessionVariables` | `homeManager` | User `~` path modification |
| `xdg.*`, `wayland.windowManager.*`, `desktopConfiguration` | `homeManager` | User-space GUI and desktop assets |
