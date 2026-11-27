# Shared by every machine (macOS and Linux).
{ config, lib, pkgs, ... }:
{
  imports = [
    ./packages.nix
    ./shell.nix
  ];

  options.my.repoPath = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/.local/share/chezmoi";
    description = "Where the dotfiles repo is checked out (the flake is in nix/).";
  };

  config = {
    # Set once at first install; don't bump it (see the HM release notes first).
    home.stateVersion = "26.11";

    home.sessionVariables.EDITOR = "vim";

    # ------------------------------------------------------------------ git
    programs.git = {
      enable = true;
      settings = {
        user.name = "Duncan Beard";
        user.email = "duncan@duncanbeard.com";
        core = {
          autocrlf = "input";
          longpaths = true;
          fileMode = false;
        };
        push.autoSetupRemote = true;
      };
      # -> ~/.config/git/ignore
      ignores = [
        "**/.vscode/**"
        "**/.claude/settings.local.json"
        ".DS_Store"
      ];
    };

    # ----------------------------------------------------------------- tmux
    programs.tmux = {
      enable = true;
      mouse = true;
      historyLimit = 100000;
      # HM writes every setting explicitly; match tmux's own defaults
      # (HM would otherwise use "screen" and a 12-hour clock).
      terminal = "tmux-256color";
      clock24 = true;
    };

    # ------------------------------------------------------------------ ssh
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      # The host list stays out of this public repo, in ~/.ssh/config.local.
      # Missing file = no-op, so fresh boxes are fine.
      includes = [ "config.local" ];
    };

    # ----------------------------------------------------- first-switch takeover
    # Files HM doesn't write itself but that would shadow what it does write.
    # Runs before HM checks for conflicts. `run` honours --dry-run.
    home.activation.retireShadowingDotfiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      # ~/.gitconfig overrides ~/.config/git/config, and
      # ~/.tmux.conf is read instead of ~/.config/tmux/tmux.conf.
      for f in "$HOME/.gitconfig" "$HOME/.tmux.conf"; do
        if [ -f "$f" ] && [ ! -L "$f" ]; then
          if [ -e "$f.pre-hm" ]; then
            warnEcho "$f shadows Home Manager's config but $f.pre-hm exists; move it aside manually"
          else
            run mv $VERBOSE_ARG "$f" "$f.pre-hm"
          fi
        fi
      done
      # Keep your existing hosts: ~/.ssh/config becomes ~/.ssh/config.local,
      # which the managed ~/.ssh/config Includes.
      if [ -f "$HOME/.ssh/config" ] && [ ! -L "$HOME/.ssh/config" ] && [ ! -e "$HOME/.ssh/config.local" ]; then
        run mv $VERBOSE_ARG "$HOME/.ssh/config" "$HOME/.ssh/config.local"
      fi
    '';
  };
}
