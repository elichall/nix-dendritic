# Tweeks — WSL + Linux (non-NixOS) Host Configuration

Want to make a platform friendly theming system for the terminal specific applications like tmux and nvim, instead of pulling from palettes i want to have them adaptively detect the theme of whatever terminal they reside in (16 ansi colors). This way all noctalia, or other toolbox hosts have to do is change their terminal emulator color scheme and it will apply to yazi, tmux, and nvim.

Have the nix write to a file in .local/share/toolbox/theme and have a script which updates tmux and nvim just like the current noctalia hook, have the palette_sync.lua fall back to the written local toolbox file if the noctalia written file does not exhist. Later I might just ignore noctalia templates and exculsively use .local share stored palettes. 
- noctalia theme changes hooks in my lightweight theme engine which takes noctalias theme and writes it to the local share path
- the hook also pings the applications to read from their files stored there and update. find a way to make this as cross platform as possible. 
