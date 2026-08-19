# Terminal emulator abstraction (DRY source).
#
# Maps a terminal name to its store path, package, and launch helpers.
# Imported from feature modules via `import ../_lib/terminal.nix { inherit pkgs terminalName; }`.
# Kept out of the import-tree because it defines no `flake.modules.*`.
#
# Hosts declare `custom.terminal` (NixOS option) and bridge it to HM via
# `home-manager.extraSpecialArgs.terminalName`. Feature modules read
# `terminalName` from their HM module args and pass it here.
{ pkgs, terminalName }:
let
  term = "${pkgs.${terminalName}}/bin/${terminalName}";
in
{
  inherit terminalName term;

  # Terminal package — add to home.packages / environment.systemPackages.
  package = pkgs.${terminalName};

  # Packages list — all terminal-specific packages. Consumer modules add this
  # to home.packages so they bring in their own dependencies even if the
  # ghostty or foot HM modules are excluded from the host.
  packages = [ pkgs.${terminalName} ];

  # Pattern A: launch a command in a new terminal window.
  exec = cmd: "${term} -e ${cmd}";

  # Pattern B: launch a command with a specific window class.
  # foot: --app-id=ID; ghostty: --class=CLASS
  execClass =
    class: cmd:
    if terminalName == "foot" then
      "${term} --app-id=${class} -e ${cmd}"
    else
      "${term} --class=${class} -e ${cmd}";
}
