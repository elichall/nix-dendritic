# ==========================================================================
# OTTER-LAUNCHER (menu / app / power launcher)
# ==========================================================================
# Ported from legacy /etc/nixos/modules/otter-launcher/ (Phase 2 — see
# modules/_assets/otter-strategy.md). Provisioned from the upstream flake
# input (inputs.otter-launcher) instead of the legacy builtins.fetchTarball
# + buildRustPackage.
#
# SCOPE: homeManager-only. Every otter concern is user-scale (the launcher,
# its wrappers, the config.toml menu modules). There is deliberately no
# nixos.otterLauncher scope — the system-scale pieces that otter touches live
# with their owning aspects:
#   - window rule for com.otter.launcher + keybinds (menu/systemManager) +
#     autostarts (otter-apps --refresh-cache, persistent ghostty server):
#     homeManager.hyprland
#   - waybar power on-click (otter-open): homeManager.waybar
#
# DISMISS (phase 1 fix, NOT the broken legacy pattern): pointer-move
# dismissal uses _lib/interaction-watch.nix with `pkill -x otter-launcher`
# (exact comm match, verified live). The bail uses --bail-comm, an exact
# `pgrep -x otter-launcher` comm match: it can never self-match the watcher's
# own cmdline, nor match the ghostty server (--class=com.otter.launcher) or the
# spawning client.
#
# RULE 4 (strategy guide §5 — Hybrid): every binary the config.toml menu
# modules shell out to via `sh -c` is declared in home.packages below so it
# reaches the launcher's PATH. System-scope binaries (hyprctl, sudo,
# systemctl, loginctl, nixos-rebuild, xdg-settings) stay PATH-based. The
# module-owned CLIs (theme, otter-apps) are covered by otter-diagnose + the
# home.activation warning hook (warn, not fail).
{ inputs, ... }: {
  flake.modules.homeManager.otterLauncher = { config, pkgs, lib, ... }: let
    # Flake-provisioned launcher binary (upstream v0.7.6 exposes
    # packages.<system>.otter-launcher via flake-parts).
    otter-launcher = inputs.otter-launcher.packages.${pkgs.stdenv.hostPlatform.system}.otter-launcher;

    # Shared pointer-dismiss helper (showoff + otter; see _lib/interaction-watch.nix).
    interactionWatch = import ../../_lib/interaction-watch.nix { inherit pkgs; };

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
    # record lives at $HOME/Projects/nix-dendritic).
    overlayImage = "${config.home.homeDirectory}/Projects/nix-dendritic/modules/_assets/nixos-image.png";

    appConfig = mkOtterConfig {
      DEFAULT_MODULE = "app";
      DEFAULT_MODULE_MESSAGE = "  └ \\u001B[34m  \\u001B[33mapp \\u001B[0m launch apps";
      OVERLAY_IMAGE = overlayImage;
    };

    powConfig = mkOtterConfig {
      DEFAULT_MODULE = "pow";
      DEFAULT_MODULE_MESSAGE = "  └ \\u001B[34m  \\u001B[33mpow \\u001B[0m power menu";
      OVERLAY_IMAGE = overlayImage;
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
        pkgs.ghostty
        interactionWatch
      ];
      text = ''
        CONFIG="''${1:-}"
        # Exact comm match (not the legacy broken `pgrep -f "/bin/otter-launcher"`):
        # the launcher process comm is `otter-launcher`, the wrappers' comm is
        # bash/otter-launch — no self-match, no ghostty over-match.
        if pgrep -x otter-launcher >/dev/null 2>&1; then
          # Toggle-close: kills only the launcher. Its window closes naturally;
          # the persistent server (if running) stays.
          pkill -x otter-launcher >/dev/null 2>&1 || true
        else
          # Fast path: hand off to the persistent com.otter.launcher instance
          # (ghostty --gtk-single-instance server autostarted by hyprland).
          # Cold fallback if the server is not running.
          if ghostty +new-window --class=com.otter.launcher -e ${otter-launch-inner}/bin/otter-launch-inner ''${CONFIG:+"$CONFIG"} >/dev/null 2>&1; then
            :
          else
            ghostty --class=com.otter.launcher -e ${otter-launch-inner}/bin/otter-launch-inner ''${CONFIG:+"$CONFIG"} &
          fi
          # Dismiss on pointer move. --bail-comm is an exact `pgrep -x
          # otter-launcher` comm match, so the watcher never matches itself,
          # the ghostty server, or the spawning client; it exits as soon as the
          # launcher is gone (ESC / ran a command), before the pointer moves.
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
    # exception (AGENTS.md / modules/_assets/otter-strategy.md §5): the
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
        check ghostty        "ghostty (Rule 4 declared)"
        check nvim           "nvim (config.toml external_editor)"
        check fzf            "fzf (app-launcher / menu pickers)"
        check chafa          "chafa (app-launcher preview / overlay)"
        check qalc           "qalc (calc module)"
        check wl-copy        "wl-clipboard (calc module)"
        check tmux           "tmux (pro/ssh modules)"
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
      with pkgs;
      [
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
        ghostty
        fzf
        chafa
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
      ];

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
