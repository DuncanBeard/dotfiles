{
  description = "Duncan's machines: nix-darwin + Home Manager (macOS), Home Manager (Linux)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager }:
  let
    inherit (nixpkgs) lib;

    # Standalone Home Manager for Linux (any distro; not NixOS).
    mkHome = { name, system, username, modules ? [ ] }:
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
        modules = [
          ./home/linux.nix
          {
            home.username = username;
            home.homeDirectory = if username == "root" then "/root" else "/home/${username}";
            my.hmConfigName = name;
          }
        ] ++ modules;
      };

    # Generic configs: "duncan@x86_64-linux", "duncan@aarch64-linux".
    # bootstrap.sh falls back to these when there's no "user@hostname" entry.
    # They're lean (no workstation packages), which suits servers and Pis.
    generic = lib.listToAttrs (lib.concatMap (system:
      map (username: rec {
        name = "${username}@${system}";
        value = mkHome { inherit name system username; };
      }) [ "duncan" ]
    ) [ "x86_64-linux" "aarch64-linux" ]);

    # Named hosts win over the generic configs (bootstrap.sh tries these first).
    hosts = {
      # "duncan@thallium" = mkHome {
      #   name = "duncan@thallium"; system = "x86_64-linux"; username = "duncan";
      #   modules = [ { my.workstation = true; } ];
      # };
    };
  in
  {
    # Build darwin flake using:
    # $ sudo darwin-rebuild switch --flake ~/.local/share/chezmoi/nix
    darwinConfigurations."Duncans-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit self; };
      modules = [
        ./darwin.nix
        nix-homebrew.darwinModules.nix-homebrew
        home-manager.darwinModules.home-manager
      ];
    };

    homeConfigurations = generic // hosts;

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Duncans-MacBook-Pro".pkgs;
  };
}
