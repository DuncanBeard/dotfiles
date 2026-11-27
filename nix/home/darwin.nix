# macOS user config (loaded by nix-darwin; see ../darwin.nix).
{ config, lib, pkgs, ... }:
{
  imports = [ ./common.nix ./ghostty.nix ];

  # Dev tools from ./packages.nix (the ones Hermes doesn't need from Homebrew).
  my.workstation = true;

  # Keep Apple's git: it reads /etc/gitconfig (Azure Repos credential setting),
  # which Nix's git wouldn't.
  programs.git.package = null;

  # Keep /bin/bash (3.2), and keep the generated bashrc 3.2-compatible:
  # bash-completion 2 and the globstar/checkjobs options need bash 4+.
  programs.bash = {
    package = null;
    enableCompletion = false;
    shellOptions = [ "histappend" "checkwinsize" "extglob" ];
  };

  # 1Password SSH agent for every host
  programs.ssh.settings."*".IdentityAgent =
    ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';

  home.shellAliases.hms = "sudo darwin-rebuild switch --flake ${config.my.repoPath}/nix";

  # ------------------------------------------------------------ Ghostty
  # Shared settings are in ./ghostty.nix. Ghostty.app itself comes from the
  # Homebrew cask (../darwin.nix). Ported from
  # ~/Library/Application Support/com.mitchellh.ghostty/config.
  programs.ghostty = {
    package = null;
    settings = {
      font-size = 16;
      # macOS: make Option work as Alt
      macos-option-as-alt = true;
      window-save-state = "always";  # macOS only
      # super = Cmd
      keybind = [
        "super+r=clear_screen"
        "super+f=toggle_fullscreen"
        "super+arrow_left=previous_tab"
        "super+arrow_right=next_tab"
      ];
    };
  };

  # Ghostty also loads its Application Support config files, which would
  # override the managed one. Move them aside on the first switch.
  home.activation.retireGhosttyAppSupportConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    d="$HOME/Library/Application Support/com.mitchellh.ghostty"
    for f in "$d/config" "$d/config.ghostty"; do
      if [ -f "$f" ] && [ ! -L "$f" ]; then
        if [ -e "$f.pre-hm" ]; then
          warnEcho "$f would override Home Manager's Ghostty config but $f.pre-hm exists; move it aside manually"
        else
          run mv $VERBOSE_ARG "$f" "$f.pre-hm"
        fi
      fi
    done
  '';

  # ---------------------------------------------------------------- zsh
  # ~/.zprofile (login shells). Dropped from the old one: the Python 3.10
  # framework PATH (brew's python3 already came first) and a duplicate ~/.local/bin.
  programs.zsh.profileExtra = ''
    eval "$(/opt/homebrew/bin/brew shellenv)"
  '';

  programs.zsh.initContent = lib.mkOrder 1050 ''
    # Added by LM Studio CLI (lms)
    export PATH="$PATH:$HOME/.lmstudio/bin"

    XDG_DATA_DIRS="/opt/homebrew/share:$XDG_DATA_DIRS"

    # Ollama models on external SSD
    export OLLAMA_MODELS="/Volumes/Models/ollama/models"

    # Hermes post-update hook: reconcile /help hotkeys and restart secure WebUI
    [ -r "$HOME/.config/hermes-hotkeys/update-hook.zsh" ] && source "$HOME/.config/hermes-hotkeys/update-hook.zsh"
  '';

  # --------------------------------------------------------------- bash
  programs.bash.shellAliases = {
    dd = "cd ~/Dropbox/Documents";

    # Get macOS Software Updates, and update installed Ruby gems, Homebrew, npm, and their installed packages
    update = "sudo softwareupdate -i -a; brew update; brew upgrade --all; brew cleanup; npm install npm -g; npm update -g; sudo gem update --system; sudo gem update";

    # IP addresses
    ip = "dig +short myip.opendns.com @resolver1.opendns.com";
    localip = "ipconfig getifaddr en0";
    ips = "ifconfig -a | grep -o 'inet6\\? \\(addr:\\)\\?\\s\\?\\(\\(\\([0-9]\\+\\.\\)\\{3\\}[0-9]\\+\\)\\|[a-fA-F0-9:]\\+\\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'";

    # Flush Directory Service cache
    flush = "dscacheutil -flushcache && killall -HUP mDNSResponder";
    # Clean up LaunchServices to remove duplicates in the "Open With" menu
    lscleanup = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder";

    # View HTTP traffic
    sniff = "sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'";
    httpdump = ''sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E "Host\: .*|GET \/.*"'';

    # Trim new lines and copy to clipboard
    c = "tr -d '\\n' | pbcopy";
    # Recursively delete `.DS_Store` files
    cleanup = "find . -type f -name '*.DS_Store' -ls -delete";
    # Empty the Trash on all mounted volumes and the main HDD, clear Apple's
    # System Logs, and clear download history from quarantine.
    emptytrash = "sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl; sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* 'delete from LSQuarantineEvent'";

    # Show/hide hidden files in Finder
    show = "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder";
    hide = "defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder";
    # Hide/show all desktop icons (useful when presenting)
    hidedesktop = "defaults write com.apple.finder CreateDesktop -bool false && killall Finder";
    showdesktop = "defaults write com.apple.finder CreateDesktop -bool true && killall Finder";

    # Spotlight
    spotoff = "sudo mdutil -a -i off";
    spoton = "sudo mdutil -a -i on";
  };

  programs.bash.initExtra = lib.mkAfter ''
    # One of @janmoesen's ProTips: GET/POST/... via lwp-request
    for method in GET HEAD POST PUT DELETE TRACE OPTIONS; do
      alias "$method"="lwp-request -m '$method'"
    done

    # iTerm shell integration
    test -e "''${HOME}/.iterm2_shell_integration.bash" && source "''${HOME}/.iterm2_shell_integration.bash"

    # Added by LM Studio CLI (lms)
    export PATH="$PATH:$HOME/.lmstudio/bin"
  '';
}
