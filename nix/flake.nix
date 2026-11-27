{
  description = "MacBook Pro Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew }:
  let
    configuration = { pkgs, ... }: {

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
        casks = [
          "the-unarchiver"
        ];
        # Leave anything installed by hand alone.
        onActivation.cleanup = "none";
      };

      fonts.packages = [
        pkgs.nerd-fonts.jetbrains-mono
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
    };
  in
  {
    # Build darwin flake using:
    # $ sudo darwin-rebuild switch --flake ~/.local/share/chezmoi/nix
    darwinConfigurations."Duncans-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
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
        }
      ];
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Duncans-MacBook-Pro".pkgs;
  };
}
