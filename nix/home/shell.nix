# zsh, bash and readline. Ported from the live ~/.zshrc, ~/.bash_profile and
# ~/.inputrc as of 2026-11-26; macOS-only bits are in ./darwin.nix.
{ config, lib, pkgs, ... }:
let
  # Shared with chezmoi (Windows), so there's one copy of the prompt theme.
  ompConfig = ../../dot_config/ohmyposh/omp.yml;
in
{
  # ------------------------------------------------------------------ zsh
  programs.zsh = {
    enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "docker" "docker-compose" ];
      # Runs just before oh-my-zsh is sourced.
      extraConfig = ''
        ZSH_THEME=""  # oh-my-posh draws the prompt
        COMPLETION_WAITING_DOTS="true"
        # oh-my-zsh is pinned by flake.lock now; update with `nix flake update`.
        zstyle ':omz:update' mode disabled
        # Docker CLI completions (must be on fpath before oh-my-zsh's compinit)
        [[ -d "$HOME/.docker/completions" ]] && fpath=("$HOME/.docker/completions" $fpath)
      '';
    };

    # HM sets history after oh-my-zsh, so restate oh-my-zsh's values
    # (lib/history.zsh) to keep behaving as before.
    history = {
      path = "${config.home.homeDirectory}/.zsh_history";
      size = 50000;
      save = 10000;
      append = true;
      share = true;
      extended = true;
      expireDuplicatesFirst = true;
      ignoreDups = true;
      ignoreSpace = true;
    };

    shellAliases = {
      cz = "chezmoi";
      reload = "source ~/.zshrc";
    };

    initContent = ''
      # PATH: same order as before (~/.local/bin first, then bun).
      # HM's `typeset -U path` drops the duplicates the old files piled up.
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$HOME/.local/bin:$BUN_INSTALL/bin:$PATH"

      # Prompt (Apple Terminal can't render it)
      if [ "$TERM_PROGRAM" != "Apple_Terminal" ]; then
        eval "$(${lib.getExe pkgs.oh-my-posh} init zsh --config ${ompConfig})"
      fi

      # Up/Down arrow: search history based on text to the left of cursor
      autoload -U up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      bindkey '^[[A' up-line-or-beginning-search
      bindkey '^[[B' down-line-or-beginning-search
      # Keep cursor at the end of the typed prefix, not end of line
      zstyle ':zle:up-line-or-beginning-search' leave-cursor no
      zstyle ':zle:down-line-or-beginning-search' leave-cursor no

      # Completions for self-installed tools, when present
      if (( $+commands[hermes] )); then
        eval "$(hermes completion zsh | sed 's/^_hermes "\$@"$/compdef _hermes hermes/')"
      fi
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
      if output="$(mole completion zsh 2>/dev/null)"; then eval "$output"; fi
    '';
  };

  # ----------------------------------------------------------------- bash
  programs.bash = {
    enable = true;
    historySize = null;  # set to "" (unlimited) in prompt.sh, as before

    shellAliases = {
      # Easier navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";
      "~" = "cd ~";
      "-" = "cd -";

      # Shortcuts
      dl = "cd ~/Downloads";
      dt = "cd ~/Desktop";
      g = "git";
      ga = "git add";
      gs = "git status";
      gb = "git checkout -b";
      h = "history";
      j = "jobs";
      be = "bundle exec";
      bi = "bundle install";
      bu = "bundle update";

      # Listings
      l = "ls -lF";
      la = "ls -laF";
      lsd = "ls -lF | grep --color=never '^d'";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";

      # Misc
      week = "date +%V";
      timer = ''echo "Timer started. Stop with Ctrl-D." && date && time cat && date'';
      # was Python 2 syntax; this is the Python 3 equivalent
      urlencode = ''python3 -c "import sys, urllib.parse as ul; print(ul.quote_plus(sys.argv[1]))"'';
      badge = "tput bel";
      map = "xargs -n1";
      size = "du -sh";  # was fused with the next line: `size` ran `du -shexport`
      reload = "exec $SHELL -l";

      # Kubernetes
      k = "kubectl";
      ka = "kubeadm";
      kcd = "kubectl --kubeconfig ~/.kube/config";
      kcm = "kubectl --kubeconfig ~/.kube/k3s-multipass.yaml";
      kcr = "kubectl --kubeconfig ~/.kube/k3s-raspberrypi.yaml";
    };

    initExtra = builtins.readFile ./bash/prompt.sh;
  };

  # ------------------------------------------------------------- readline
  programs.readline = {
    enable = true;
    includeSystemConfig = false;  # the old ~/.inputrc didn't include /etc/inputrc
    variables.history-preserve-point = true;
    bindings = {
      # Up/Down: search history for the typed prefix
      "\\e[A" = "history-search-backward";
      "\\e[B" = "history-search-forward";
      # Word movement: Ctrl/Alt + Left/Right
      "\\e[1;5C" = "forward-word";
      "\\e[1;5D" = "backward-word";
      "\\e[5C" = "forward-word";
      "\\e[5D" = "backward-word";
      "\\e\\e[C" = "forward-word";
      "\\e\\e[D" = "backward-word";
    };
  };
}
