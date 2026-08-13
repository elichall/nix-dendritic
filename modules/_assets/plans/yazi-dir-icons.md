# Yazi Default Directory Name Icons

> **STATUS: IMPLEMENTED (2026-08-12)** — `modules/programs/yazi.nix` adds
> `theme.icon` custom dir + config-folder icons (plan dirs + package icons).
> NOTE 1 (2026-08-12): yazi 26.x renamed the icon schema — `prepend_rules`
> was removed silently; the module now uses `prepend_dirs` / `prepend_files`
> keyed by exact name (no trailing slash). Do NOT reintroduce `prepend_rules`.
> NOTE 2: `vault/` uses the obsidian glyph U+E6BB (`nf custom obsidian`), which
> was added to Nerd Fonts in v3.5.0 — renders as "?" until nixos-26.05 bumps
> nerd-fonts past 3.4.0 (deferred per user decision 2026-08-12).

Yazi has some icons it uses by default for standard directory or file names like ...

*.nix

*.lock

.git/ or .gitignore

Documents/ Downloads/ Pictures/

I want to have some custom ones like ...

Projects/ with a wrench 

Box/ with the 󰍲 

.nix/ 󱄅 

wallpapers/ 󰸉

.var/ with something flatpak related 

vault/ with obsidian nerd icon  (i don't have this font installed)

see [[../nerd_font_icons.md]] for any package specific icons i have found, they can be applied to their respective .config/ folders and files.

ex. hyprland/ and hyprland.{lua,conf} can have the  icon added
