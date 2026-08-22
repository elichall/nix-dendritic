# ==========================================================================
# CLIPBOARD — platform-aware userland integration
# ==========================================================================
# Branches on the host scaffold (contract C28): displayProtocol selects the
# protocol tools; isWsl adds Windows interop. WSL keeps BOTH protocol stacks
# because WSLg exposes wayland AND x11 simultaneously — tools auto-detect
# either and fail with exit 127 if their backend binary is missing.
#
# WSL shims (nixpkgs gaps):
# - win32yank absent from nixpkgs; fetched from upstream release. It is a PE
#   binary executed through WSL interop. Installed under both names because
#   nvim's provider probes `win32yank.exe` then falls back to `win32yank`.
# - wslu was removed from nixpkgs (project archived); `wslview` shimmed via
#   cmd.exe start (opens URL/file in the Windows default handler; consumed by
#   md-view.nvim).
{ inputs, ... }: {
  flake.modules.homeManager.clipboard = { config, pkgs, lib, ... }:
    let
      win32yank-src = pkgs.fetchzip {
        url = "https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x64.zip";
        # zip holds a bare win32yank.exe (no root folder)
        stripRoot = false;
        hash = "sha256-VkTcO0HxGAeXBrqvxJcXkP2p4iIJLmTlbeecvtQX68s=";
      };
      win32yank = pkgs.runCommand "win32yank-0.0.4" { } ''
        install -Dm755 ${win32yank-src}/win32yank.exe $out/bin/win32yank.exe
        ln -s win32yank.exe $out/bin/win32yank
      '';
      wslview = pkgs.writeShellScriptBin "wslview" ''
        exec /mnt/c/Windows/System32/cmd.exe /c start "" "$@"
      '';
    in {
      home.packages =
        lib.optionals (config.host.displayProtocol == "wayland") [ pkgs.wl-clipboard ]
        ++ lib.optionals (config.host.displayProtocol == "x11") [ pkgs.xclip ]
        ++ lib.optionals config.host.isWsl [
          win32yank
          wslview
          # WSLg also exposes x11; some tools still pick xclip — ship both.
          pkgs.xclip
        ];
    };
}
