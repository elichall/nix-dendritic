# ==========================================================================
# TMUX
# ==========================================================================
{ inputs, ... }: {
  flake.modules.homeManager.tmux = { pkgs, ... }: {
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
            set -g @resurrect-strategy-nvim 'session'
            set -g @resurrect-processes "opencode"
            set -g @resurrect-dir '~/.local/share/tmux/resurrect'
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
        set-option -g detach-on-destroy off

        set -g pane-base-index 1
        set-window-option -g pane-base-index 1
        set-option -g renumber-windows on

        if-shell '[ -f ~/.config/tmux/colors.tmux ]' 'source-file ~/.config/tmux/colors.tmux'

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
  };
}
