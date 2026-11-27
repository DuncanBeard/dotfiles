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

    # Most CLI tools come from nixpkgs (home/packages.nix). These stay in
    # Homebrew because the Hermes and OpenClaw LaunchAgents hard-code
    # /opt/homebrew (PATH, signal-cli, node) and run them, or because nixpkgs
    # doesn't have them (cliclick, imagesnap, memo, imsg, remindctl,
    # notesmd-cli, summarize, mole), or they're libraries for builds outside
    # Nix (sdl2_*, libuvc). Already installed here, so activation is a no-op.
    # Removing a brew from this list doesn't uninstall it (cleanup = "none").
    taps = [
      "antoniorodr/memo"
      "steipete/tap"
      "yakitrak/yakitrak"
    ];
    brews = [
      "antoniorodr/memo/memo" "azcopy" "cliclick" "cmake" "docker"
      "docker-compose" "gh" "ghostscript" "go" "himalaya" "imagesnap" "kubernetes-cli"
      "libuvc" "llama.cpp" "mole" "openai-whisper" "opencode" "poppler" "qemu"
      "sdl2_image" "sdl2_ttf" "signal-cli" "sshpass" "steipete/tap/imsg"
      "steipete/tap/remindctl" "summarize" "yakitrak/yakitrak/notesmd-cli"
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
