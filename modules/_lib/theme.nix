# Shared theme-engine paths (DRY source). Path indirection architecture:
# modules/_assets/module-contracts.md (C2). The theme engine is
# path-indirected: no Nix config encodes a theme value; ghostty.nix and
# theme.nix must agree on these paths.
{ home }:
{
  # Root state dir for the theme engine
  dir = "${home}/.local/share/theme";

  # The active-theme pointer (persistent; survives rebuilds/reboots)
  active = "${home}/.local/share/theme/active.json";

  # Runtime-generated configs + palettes
  generated = "${home}/.local/share/theme/generated";

  # ghostty picks this up via `config-file` in ghostty.nix. sync-ghostty
  # rewrites it (theme = <name>) at runtime; the path never changes so a
  # home-manager switch can never reset the active theme.
  ghosttyThemeConf = "${home}/.local/share/theme/generated/ghostty/theme.conf";
}
