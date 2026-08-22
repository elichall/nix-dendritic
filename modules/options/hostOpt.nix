# ==========================================================================
# HOST OPTIONS — scaffolding for what a host can be (both scopes)
# ==========================================================================
# The possibility space of a target machine, declared per class so feature
# aspects branch on `config.host.*` regardless of evaluation scope. Defaults
# encode standard practice; hosts override identity choices explicitly.
#
# CROSS-SCOPE DEFAULT SHARING: the two scopes are separate module-system
# evaluations — an HM default can never read nixos-scope config (and
# standalone-HM hosts have no nixos eval at all). Shared default VALUES
# therefore live in the `stdPractice` let below: one source of truth consumed
# by both declarations. Semantic inheritance (gitUsername <- username) uses a
# same-scope config reference instead.
#
# Precedence ladder: option default < mkDefault < explicit assignment <
# mkForce. Override at whichever scope owns the concern.
# ==========================================================================
{ lib, ... }:
let
  # Standard-practice defaults — single source for both scopes.
  stdPractice = {
    isNixos = true;
    isWsl = false;
    displayProtocol = "wayland";
    shell = "bash";
    supportedShells = [
      "bash"
      "zsh"
      "fish"
      "nushell"
    ];
    identity.username = "elichall";
    identity.email = "1elijah.hall@gmail.com";
  };
in
{
  flake.modules.nixos.optionsHost = { config, ... }: {
    options.host = {
      # Tautological inside nixosSystem (a NixOS eval IS NixOS); its real
      # consumer is the HM copy below — standalone-HM hosts set false to
      # enable foreign-distro behavior (e.g. targets.genericLinux).
      isNixos = lib.mkOption {
        type = lib.types.bool;
        default = stdPractice.isNixos;
        description = ''
          Whether this evaluation targets NixOS rather than a foreign distro
          via standalone Home Manager.
        '';
      };

      # Both WSL flavors exist: NixOS-in-WSL (nixosConfigurations + nixos-wsl)
      # and toolbox-style standalone HM inside a foreign WSL distro. isWsl +
      # isNixos compose to distinguish them.
      isWsl = lib.mkOption {
        type = lib.types.bool;
        default = stdPractice.isWsl;
        description = "Target runs under Windows Subsystem for Linux.";
      };

      displayProtocol = lib.mkOption {
        type = lib.types.enum [
          "x11"
          "wayland"
        ];
        default = stdPractice.displayProtocol;
        description = ''
          Display protocol available to userland. WSLg exposes wayland, so it
          counts even without a full desktop; relevant for clipboard tooling.
        '';
      };

      shell = lib.mkOption {
        type = lib.types.enum stdPractice.supportedShells;
        default = stdPractice.shell;
        description = "Interactive login shell.";
      };

      identity = {
        username = lib.mkOption {
          type = lib.types.str;
          default = stdPractice.identity.username;
          description = "Primary user account name.";
        };
        email = lib.mkOption {
          type = lib.types.str;
          default = stdPractice.identity.email;
          description = "Canonical contact email.";
        };
        gitUsername = lib.mkOption {
          type = lib.types.str;
          default = config.host.identity.username;
          description = "Name stamped into commits; inherits username unless overridden.";
        };
        gitEmail = lib.mkOption {
          type = lib.types.str;
          default = config.host.identity.email;
          description = "Email stamped into commits; inherits email unless overridden.";
        };
      };
    };
  };

  flake.modules.homeManager.optionsHost = { config, ... }: {
    options.host = {
      isNixos = lib.mkOption {
        type = lib.types.bool;
        default = stdPractice.isNixos;
        description = ''
          False when this HM tree runs standalone on a foreign distro
          (consumer: targets.genericLinux.enable).
        '';
      };
      isWsl = lib.mkOption {
        type = lib.types.bool;
        default = stdPractice.isWsl;
        description = "Consumer: clipboard/cmdLine WSL branching (win32yank, wslu).";
      };
      displayProtocol = lib.mkOption {
        type = lib.types.enum [
          "x11"
          "wayland"
        ];
        default = stdPractice.displayProtocol;
        description = "Consumer: clipboard package selection.";
      };
      shell = lib.mkOption {
        type = lib.types.enum stdPractice.supportedShells;
        default = stdPractice.shell;
        description = "Consumer: cmdLine shell selection.";
      };
      identity = {
        username = lib.mkOption {
          type = lib.types.str;
          default = stdPractice.identity.username;
          description = "Primary user account name.";
        };
        email = lib.mkOption {
          type = lib.types.str;
          default = stdPractice.identity.email;
          description = "Canonical contact email.";
        };
        gitUsername = lib.mkOption {
          type = lib.types.str;
          default = config.host.identity.username;
          description = "Name stamped into commits (consumer: git aspect).";
        };
        gitEmail = lib.mkOption {
          type = lib.types.str;
          default = config.host.identity.email;
          description = "Email stamped into commits (consumer: git aspect).";
        };
      };
    };
  };
}
