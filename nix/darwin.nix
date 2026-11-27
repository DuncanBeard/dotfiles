# nix-darwin system configuration for Duncans-MacBook-Pro.
# Everything above the Home Manager section is unchanged from the original
# ~/.config/nix/flake.nix.
{ self, pkgs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search by name, run:
  # $ nix search nixpkgs <name>
  environment.systemPackages =
    [ pkgs.neovim
      pkgs.vim
      pkgs.tmux
      pkgs.alacritty
      pkgs.openscad
      pkgs.vscode
      pkgs.herdr
      pkgs.herdr-core
      pkgs.herdr-desktop
    ];

  # Apps from systemPackages are linked into /Applications/Nix Apps
  # automatically by nix-darwin; no custom activation script needed.

  homebrew = {
    enable = true;
    # Leave anything installed by hand alone.
    onActivation.cleanup = "none";

    # On macOS, Homebrew stays the source of CLI tools for now: the Hermes and
    # OpenClaw LaunchAgents hard-code /opt/homebrew (PATH, signal-cli, node).
    # This list is the `brew leaves` set as of 2026-11-26, declared so a new
    # Mac gets the same tools. Already installed here, so activation is a no-op.
    taps = [
      "antoniorodr/memo"
      "golangci/tap"
      "hashicorp/tap"
      "steipete/tap"
      "yakitrak/yakitrak"
    ];
    brews = [
      "antoniorodr/memo/memo" "asciinema" "azcopy" "chezmoi" "cliclick" "cmake"
      "czkawka" "docker" "docker-compose" "doggo" "gh" "ghostscript" "go"
      "golangci/tap/golangci-lint" "hashicorp/tap/terraform" "helm" "himalaya"
      "imagesnap" "iperf3" "k9s" "ko" "lazydocker" "libimobiledevice"
      "libirecovery" "libnfc" "libuvc" "llama.cpp" "lld" "meson" "minikube"
      "mole" "moreutils" "ncdu" "neovim" "nmap" "openai-whisper" "opencode"
      "poppler" "qemu" "qrencode" "ranger" "sdl2_image" "sdl2_ttf" "signal-cli"
      "socat" "sshpass" "steipete/tap/imsg" "steipete/tap/remindctl" "summarize"
      "tmux" "watch" "wget" "xcodegen" "yakitrak/yakitrak/notesmd-cli"
    ];
    casks = [
      "balenaetcher"
      "ghostty"
      "github-copilot-for-xcode"
      "meld"
      "signal"
      "the-unarchiver"
      "virtualbuddy"
    ];
  };

  nix-homebrew = {
    # Install Homebrew under the default prefix
    enable = true;

    # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
    enableRosetta = true;

    # User owning the Homebrew prefix
    user = "duncan";

    # Take over the existing /opt/homebrew installation in place.
    autoMigrate = true;

    # Keep `brew tap` working for existing and future taps.
    mutableTaps = true;
  };

  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    # Ghostty's font (home/darwin.nix). Nerd Font build, so prompt icons render.
    pkgs.nerd-fonts.hack
  ];

  # Determinate Nix manages the Nix installation and daemon itself
  # (flakes are already enabled). Put extra Nix settings in
  # /etc/nix/nix.custom.conf instead of nix.settings.
  nix.enable = false;

  # User that owns user-level options (homebrew, defaults, etc.).
  system.primaryUser = "duncan";

  # Touch ID for sudo (managed via /etc/pam.d/sudo_local).
  security.pam.services.sudo_local.touchIdAuth = true;

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true;  # default shell on catalina

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # ------------------------------------------------------------ Home Manager
  users.users.duncan.home = "/Users/duncan";

  home-manager = {
    useGlobalPkgs = true;    # share this nixpkgs (and allowUnfree)
    useUserPackages = true;  # install to /etc/profiles/per-user/duncan
    # Existing files HM would replace get renamed to <file>.pre-hm on first switch.
    backupFileExtension = "pre-hm";
    users.duncan = ./home/darwin.nix;
  };
}
