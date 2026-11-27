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

    # Graphics drivers for Nix GUI apps. Upstream turns this on by default,
    # which costs every server ~1 GiB (mesa) plus a setup warning on each
    # switch. Only machines with a screen need it (see steamdeck.nix).
    targets.genericLinux.gpu.enable = lib.mkDefault false;

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
