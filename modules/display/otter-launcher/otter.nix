# ==========================================================================
# OTTER-LAUNCHER (menu / app / power launcher)
# ==========================================================================
# Scope/provenance, dismiss contract, Rule 4 Hybrid: modules/_assets/
# documentation/module-contracts.md (C5/C6) + documentation/decisions.md.
# ==========================================================================
{ inputs, ... }: {
  flake.modules.homeManager.otterLauncher = { config, pkgs, lib, terminalName, ... }: let
    # Flake-provisioned launcher binary (upstream v0.7.6 exposes
    # packages.<system>.otter-launcher via flake-parts).
    otter-launcher = inputs.otter-launcher.packages.${pkgs.stdenv.hostPlatform.system}.otter-launcher;

    # Terminal abstraction — provides exec/execClass helpers + package.
    terminal = import ../../_lib/terminal.nix { inherit pkgs terminalName; };

    # Shared pointer-dismiss helper (showoff + otter; see _lib/interaction-watch.nix).
    interactionWatch = import ../../_lib/interaction-watch.nix { inherit pkgs; };

    # Shared theme-engine paths (contract: theme.nix owns profiles/ +
    # generated/previews/; the otter th module preview reads them).
    themeLib = import ../../_lib/theme.nix { home = config.home.homeDirectory; };

    # config.toml is a template: the injectable lines use @TOKEN@ placeholders.
    # mkOtterConfig substitutes them, so each menu variant (app, pow, ...) is
    # just an attrset of values. Add a token in config.toml + a field here.
    mkOtterConfig =
      overrides:
      let
        tokens = builtins.attrNames overrides;
      in
      pkgs.writeText "otter-launcher.toml" (
        builtins.replaceStrings (builtins.map (token: "@${token}@") tokens) (builtins.map (
          token: overrides.${token}
        ) tokens) (builtins.readFile ./config.toml)
      );

    # Repo-relative asset path (same assumption ned/nrb make: the config of
    # record lives at $HOME/.nix).
    overlayImage = "${config.home.homeDirectory}/.nix/modules/_assets/aesthetics/nixos-image.png";

    appConfig = mkOtterConfig {
      DEFAULT_MODULE = "app";
      DEFAULT_MODULE_MESSAGE = "  └ \\u001B[34m  \\u001B[33mapp \\u001B[0m launch apps";
      OVERLAY_IMAGE = overlayImage;
      THEME_DIR = themeLib.dir;
      THEME_SWATCHES = "${themeLib.generated}/previews";
    };

    powConfig = mkOtterConfig {
      DEFAULT_MODULE = "pow";
      DEFAULT_MODULE_MESSAGE = "  └ \\u001B[34m  \\u001B[33mpow \\u001B[0m power menu";
      OVERLAY_IMAGE = overlayImage;
      THEME_DIR = themeLib.dir;
      THEME_SWATCHES = "${themeLib.generated}/previews";
    };

    otter-launch-inner = pkgs.writeShellApplication {
      name = "otter-launch-inner";
      runtimeInputs = [
        otter-launcher
        pkgs.coreutils
      ];
      text = ''
        if [ -n "''${1:-}" ]; then
          exec otter-launcher -c "$1"
        else
          exec otter-launcher
        fi
      '';
    };

    otter-launch = pkgs.writeShellApplication {
      name = "otter-launch";
      runtimeInputs = [
        pkgs.procps
        pkgs.coreutils
        terminal.package
        interactionWatch
      ];
      text = let
        otterCmd = terminal.execClass "com.otter.launcher" "${otter-launch-inner}/bin/otter-launch-inner \"$CONFIG\"";
      in ''
        CONFIG="''${1:-}"
        if pgrep -x otter-launcher >/dev/null 2>&1; then
          pkill -x otter-launcher >/dev/null 2>&1 || true
        else
          ${otterCmd} &
          interaction-watch --tag otter --grace 0.5 --interval 0.1 \
            --bail-comm otter-launcher \
            --on-move 'pkill -x otter-launcher' &
          disown
        fi
      '';
    };

    otter-open = pkgs.writeShellScriptBin "otter-open" ''
      exec otter-launch
    '';

    otter-power = pkgs.writeShellScriptBin "otter-power" ''
      exec otter-launch ${powConfig}
    '';

    app-launcher = pkgs.writeShellApplication {
      name = "otter-apps";
      runtimeInputs = [
        pkgs.fzf
        pkgs.chafa
        pkgs.gawk
        pkgs.gnugrep
        pkgs.coreutils
        pkgs.util-linux
      ];
      text = builtins.readFile ./app-launcher.sh;
    };

    # Dependency audit: lists every binary the launcher shells out to, its
    # provider, and whether it is reachable on PATH. Covers the Rule 4 Hybrid
    # exception (AGENTS.md / modules/_assets/documentation/decisions.md #24): the
    # module-owned CLIs (theme, otter-apps) cannot be re-declared as
    # home.packages here, so they are audited instead of assumed. Exit code is
    # non-zero when anything is missing so the home.activation hook below can
    # warn (it never fails the build).
    otter-diagnose = pkgs.writeShellApplication {
      name = "otter-diagnose";
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        set -u
        ok=0
        missing=0
        check() {
          local bin="$1" provider="$2"
          if command -v "$bin" >/dev/null 2>&1; then
            printf 'OK      %-16s %s\n' "$bin" "$provider"
            ok=$((ok+1))
          else
            printf 'MISSING %-16s %s\n' "$bin" "$provider"
            missing=$((missing+1))
          fi
        }
        check otter-launcher "otter module (self)"
        check otter-apps     "otter module (self)"
        check "${terminal.term}" "${terminal.terminalName} (terminal backend)"
        check nvim           "nvim (config.toml external_editor)"
        check fzf            "fzf (app-launcher / menu pickers)"
        check chafa          "chafa (app-launcher preview / overlay / th preview)"
        check jq             "jq (th module theme preview)"
        check qalc           "qalc (calc module)"
        check wl-copy        "wl-clipboard (calc module)"
        check tmux           "tmux (pro/ssh/tsm modules)"
        check tailscale      "tailscale (ssh module)"
        check hyprctl        "hyprland"
        check xdg-open       "xdg-utils (nsp/gg modules)"
        check xdg-settings   "xdg-utils (nsp/gg modules)"
        check sudo           "sudo (ned/nrb modules)"
        check systemctl      "systemd (pow module)"
        check loginctl       "systemd (pow module)"
        check nixos-rebuild  "nixos (nrb module)"
        check theme          "theme CLI (module-owned, Rule 4 exception)"
        echo
        printf 'summary: %d ok, %d missing\n' "$ok" "$missing"
        if [ "$missing" -ne 0 ]; then
          echo "warning: missing binaries break the corresponding otter menu modules"
          exit 1
        fi
      '';
    };
  in {
    home.packages =
      terminal.packages
      ++ (with pkgs; [
        # Launcher + wrappers
        otter-launcher
        otter-open
        otter-power
        otter-launch
        otter-launch-inner
        app-launcher
        otter-diagnose
        interactionWatch

        # Rule 4 (strategy guide §5): config.toml menu modules shell out to
        # these via `sh -c` inside the launcher's environment. Declared at
        # user scope so the HM profile PATH carries them. (Duplicates across
        # modules are explicitly allowed by AGENTS.md Rule 4.)
        fzf
        chafa
        jq
        libqalculate
        wl-clipboard
        neovim
        tmux
        tailscale
        xdg-utils
        procps
        util-linux
        gawk
        gnugrep
      ]);

    xdg.configFile."otter-launcher/config.toml" = {
      force = true;
      source = appConfig;
    };

    # Rule 4 Hybrid warning hook: audits the module-owned CLIs + declared deps
    # after every switch and warns (never fails) when the launcher's menu
    # modules would be missing binaries. PATH is extended with the HM + system
    # profiles because activation may run before the session PATH is settled.
    home.activation.otterDiagnose = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="$PATH:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      if ! REPORT=$(${otter-diagnose}/bin/otter-diagnose); then
        echo "otter-launcher: warning — some menu dependencies are missing (see MISSING lines below):" >&2
        printf '%s\n' "$REPORT" | ${pkgs.gnugrep}/bin/grep 'MISSING' >&2
      fi
    '';
  };
}
