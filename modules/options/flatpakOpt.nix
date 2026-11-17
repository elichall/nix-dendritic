# Flatpak app registry — declares `flatpak.apps.<app-id>`.
# Producers: one module per app in modules/programs/flatpak/ (each sets its entry).
# Consumers: programs/flatpak/flatpak.nix (override files + .desktop entries),
# system/mime.nix (default apps), display/hyprland.nix (window rules).
# Contract + workflow: modules/_assets/documentation/module-contracts.md,
# .agents/skills/flatpak-apps/SKILL.md. Importing an app's module on a host IS
# what enables its quirks there; hosts without it get none of them.
{ ... }: {
  flake.modules.homeManager.optionsFlatpak = { lib, ... }: {
    options.flatpak.apps = lib.mkOption {
      default = { };
      description = "Hand-installed flatpak apps and the settings each needs, keyed by flatpak app ID.";
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          desktopId = lib.mkOption {
            type = lib.types.str;
            default = "${name}.desktop";
            description = "Desktop file ID (used for mime default applications).";
          };
          overrides = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Contents of ~/.local/share/flatpak/overrides/<app-id> (HM-owned, read-only; empty = no file).";
          };
          mimeTypes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "MIME types this app is the default handler for.";
          };
          windowRules = lib.mkOption {
            type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
            default = [ ];
            description = "Hyprland window rules (hl.window_rule tables: name, match, and rule keys such as center).";
          };
          desktopEntry = lib.mkOption {
            type = lib.types.nullOr lib.types.lines;
            default = null;
            description = "Contents of ~/.local/share/applications/<app-id>.desktop (null = use the flatpak's own).";
          };
          notes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Manual steps the app needs that Nix cannot own (app-owned config files, first-run settings). Informational.";
          };
        };
      }));
    };
  };
}
