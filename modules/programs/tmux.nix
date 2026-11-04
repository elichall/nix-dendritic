# ==========================================================================
# TMUX
# ==========================================================================
{ inputs, ... }: {
  flake.modules.homeManager.tmux =
    { pkgs, ... }:
    let
      palette_backup = {
        bg = "#000000";
        fg = "#ebdbb2";
        black = "#282828";
        red = "#cc241d";
        green = "#98971a";
        yellow = "#d79921";
        blue = "#458588";
        magenta = "#b16286";
        cyan = "#689d6a";
        white = "#a89984";
        gray = "#928374";
      };

      # tmux-resurrect helpers (see decisions.md #63 for the full diagnosis).
      #
      # 1. Empty pane title => corrupted save. resurrect reads its records with a
      #    tab-IFS `read`, which collapses an empty title field, so the whole row
      #    shifts left one column and the directory is lost (pane restores in
      #    $HOME, its program is not relaunched). A sticky blank title is easy to
      #    get - Claude Code blanks it on exit. Repair: re-insert a placeholder
      #    title and drop the leaked pid column. Runs on every new save
      #    (post-save-layout, gets the file path) and before every restore
      #    (pre-restore-all, repairs older saves).
      resurrectFixTitles = pkgs.writeShellApplication {
        name = "resurrect-fix-titles";
        runtimeInputs = [ pkgs.gawk pkgs.coreutils pkgs.tmux ];
        text = ''
          file="''${1:-}"
          if [ -z "$file" ]; then
            dir="$(tmux show-option -gqv @resurrect-dir)"
            dir="''${dir/#\~/$HOME}"
            file="$(readlink -f "$dir/last")"
          fi
          [ -f "$file" ] || exit 0
          tmp="$(mktemp)"
          awk -F'\t' -v OFS='\t' '
            $1 == "pane" && NF == 11 && $7 ~ /^:\// { print $1,$2,$3,$4,$5,$6,"-",$7,$8,$9,$11; next }
            { print }
          ' "$file" > "$tmp"
          cat "$tmp" > "$file"
          rm -f "$tmp"
        '';
      };

      # 2. Relaunch nvim/yazi/opencode. resurrect's own `@resurrect-processes`
      #    match needs the saved command to START with the name, but on NixOS it
      #    is a store path (/nix/store/…/bin/nvim --cmd lua …;…, whose `;` also
      #    breaks a re-sent command line), so nothing ever matched. It also sends
      #    keys the instant a pane is created, before the shell (ble.sh) is ready,
      #    and Enter gets swallowed. So: wait for the shells, then send the plain
      #    command name to panes that were running one and are now at a shell.
      resurrectRelaunch = pkgs.writeShellApplication {
        name = "resurrect-relaunch-programs";
        runtimeInputs = [ pkgs.gawk pkgs.coreutils pkgs.tmux ];
        text = ''
          sleep 3
          dir="$(tmux show-option -gqv @resurrect-dir)"
          dir="''${dir/#\~/$HOME}"
          last="$(readlink -f "$dir/last")"
          [ -f "$last" ] || exit 0
          awk -F'\t' -v OFS='\t' '
            $1 == "pane" {
              cmd = $(($7 ~ /^:\//) ? 9 : 10)
              if (cmd == "nvim" || cmd == "yazi" || cmd == "opencode") print $2, $3, $6, cmd
            }
          ' "$last" |
          while IFS=$'\t' read -r session window pane cmd; do
            target="$session:$window.$pane"
            cur="$(tmux display-message -p -t "$target" '#{pane_current_command}' 2>/dev/null)" || continue
            case "$cur" in
              bash|zsh|fish|sh) tmux send-keys -t "$target" "$cmd" C-m ;;
            esac
          done
        '';
      };
    in
    {
      programs.tmux = {
        enable = true;
        shortcut = "Space";
        baseIndex = 1;
        keyMode = "vi";
        escapeTime = 0;
        mouse = true;

        plugins = with pkgs.tmuxPlugins; [
          sensible
          vim-tmux-navigator
          {
            plugin = extrakto;
            extraConfig = ''
              set -g @extrakto_key "f"
              set -g @extrakto_filter_order "line word all"
            '';
          }
          {
            plugin = resurrect;
            extraConfig = ''
              set -g @resurrect-dir '~/.local/share/tmux/resurrect'
              # nvim/yazi/opencode are NOT listed in @resurrect-processes: the
              # built-in match can't see through Nix store paths. They are
              # relaunched by the post-restore hook below instead.
              set -g @resurrect-hook-post-save-layout '${resurrectFixTitles}/bin/resurrect-fix-titles'
              set -g @resurrect-hook-pre-restore-all '${resurrectFixTitles}/bin/resurrect-fix-titles'
              set -g @resurrect-hook-post-restore-all '${resurrectRelaunch}/bin/resurrect-relaunch-programs'
            '';
          }
          {
            plugin = continuum;
            extraConfig = ''
              set -g @continuum-restore 'on'
              set -g @continuum-save-interval 5
            '';
          }
          {
            plugin = tmux-fzf;
            extraConfig = ''
              TMUX_FZF_LAUNCH_KEY="tab"
            '';
          }
          {
            plugin = yank;
          }
        ];

        extraConfig = ''
          set -g default-terminal "tmux-256color"
          set -ag terminal-overrides ",xterm-256color:RGB"
          # Kitty graphics protocol (yazi image/PDF previews) rides DCS/APC
          # escape sequences that tmux drops by default since 3.3 — allow
          # them through so yazi can talk to the outer kitty terminal.
          set -g allow-passthrough on
          # tmux's own default update-environment already refreshes DISPLAY
          # on reattach but never covered Wayland — append WAYLAND_DISPLAY
          # so nvim's built-in clipboard auto-detection sees whichever
          # client is actually attached right now, not whichever one
          # originally created this (possibly long-lived) session.
          set -ga update-environment "WAYLAND_DISPLAY"
          set-option -g detach-on-destroy off

          set -g pane-base-index 1
          set-window-option -g pane-base-index 1
          set-option -g renumber-windows on

          if-shell '[ -f ~/.config/tmux/colors.tmux ]' \
            'source-file ~/.config/tmux/colors.tmux' \
            'source-file ~/.config/tmux/colors.fallback.tmux'

          unbind [
          bind v copy-mode
          set-window-option -g mode-keys vi
          bind-key -T copy-mode-vi v send-key -X begin-selection
          bind-key -T copy-mode-vi C-v send-key -X rectangle-toggle
          bind-key -T copy-mode-vi y send-key -X copy-selection-and-cancel
          bind-key -T copy-mode-vi Escape send-key -X cancel

          bind p run "wl-paste -n | tmux load-buffer - ; tmux paste-buffer"

          # Pane management
          unbind '"'
          unbind %
          bind | split-window -h -c "#{pane_current_path}"
          bind _ split-window -v -c "#{pane_current_path}"
          bind b break-pane -d

          bind -r Left resize-pane -L 10
          bind -r Down resize-pane -D 10
          bind -r Up resize-pane -U 10
          bind -r Right resize-pane -R 10

          bind C-x confirm-before -p "Kill all other panes in window? (y/n)" "kill-pane -a"

          # Window management
          bind n new-window -c "#{pane_current_path}"
          bind -n M-h previous-window
          bind -n M-l next-window
          bind X confirm-before -p "Kill current window? (y/n)" kill-window

          # Session management
          bind N run-shell -b "${pkgs.tmuxPlugins.tmux-fzf}/share/tmux-plugins/tmux-fzf/scripts/session.sh new"
          bind S run-shell "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/save.sh"
          bind s run-shell "${pkgs.tmuxPlugins.tmux-fzf}/share/tmux-plugins/tmux-fzf/scripts/session.sh"

          bind -n M-C-h switch-client -p
          bind -n M-C-l switch-client -n

          bind C-X confirm-before -p "Kill current session? (y/n)" "run-shell 'tmux has-session -t main 2>/dev/null || tmux new-session -d -s main; tmux switch-client -t main && tmux kill-session -t \"#{session_name}\"'"
          bind M-C-X confirm-before -p "Clear all sessions except main? (y/n)" "run-shell 'tmux has-session -t main 2>/dev/null || tmux new-session -d -s main; tmux list-sessions -F \"##S\" | grep -v \"^main$\" | xargs -I {} tmux kill-session -t {}'"
        '';
      };
      xdg.configFile."tmux/colors.fallback.tmux".text = ''
        set -g status-style "bg=${palette_backup.bg},fg=${palette_backup.fg}"
        set -g status-left "#[fg=${palette_backup.bg},bg=${palette_backup.green},bold] 󰨖 #S #[bg=default,fg=default] "

        set -g window-status-format "#[fg=${palette_backup.gray},bg=default] #I:#W "
        set -g window-status-current-format "#[fg=#000000,bg=${palette_backup.gray},bold] #I:#W "
        set -g window-status-separator ""

        set -g pane-border-style "fg=${palette_backup.gray}"
        set -g pane-active-border-style "fg=${palette_backup.green}"
        set -g message-style "bg=default,fg=${palette_backup.green},bold"
      '';
    };
}
