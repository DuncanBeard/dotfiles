# Linux user config (standalone Home Manager; see mkHome in ../flake.nix).
{ config, lib, pkgs, ... }:
{
  imports = [ ./common.nix ];

  options.my.hmConfigName = lib.mkOption {
    type = lib.types.str;
    description = "This machine's homeConfigurations name (set by mkHome).";
  };

  config = {
    # Non-NixOS fixes: XDG_DATA_DIRS, Nix env in shells, distro zsh functions.
    targets.genericLinux.enable = true;

    # Puts the pinned `home-manager` command on PATH.
    programs.home-manager.enable = true;

    home.shellAliases.hms =
      "home-manager switch --flake ${config.my.repoPath}/nix#${config.my.hmConfigName}";

    # Small disks (Pis): collect old generations and garbage weekly.
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}
