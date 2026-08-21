# List of Noticed Bugs and Desired Changes from Noctalia Desktop Transfer

## Bugs
- otter launcher terminal calls like nrb module or ned don't work (the terminal doesn't pop up fzf choosing does
    - config.toml in otter-launcher/ is hard coded to ghostty, may have to transfer whole config file over to native nix xdg write config so the terminal ingestion works 

## Changes
- Many of the tui apps are useless now as noctalia has native ways to do what they do, prune the tui apps for the noctalia desktop (ex. bluetui, wlctl not needed, btop, gdu useful)
- add a mine app registered noctalia settings app and a system control panel app (to open noctalia's native systems control panel)
- repurpose the theme module (and theme engine) in otter to simply send coupled wallpaper and theme selection noctalia cli commands that I list in nix somewhere (replacement for the experimental engine that still lets me set custom palette + wallpaper combos (or use noctalia builtin/wallpaper palette)) 
