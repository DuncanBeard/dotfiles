# CLI packages from nixpkgs. Linux only for now: on macOS, Homebrew stays the
# source (see darwin.nix), because LaunchAgents hard-code /opt/homebrew.
# The lists mirror the Mac's `brew leaves` where that makes sense on Linux.
{ config, lib, pkgs, ... }:
let
  # Everywhere, including small servers and Pis.
  core = with pkgs; [
    doggo
    gh
    iperf3
    moreutils
    ncdu
    neovim
    nmap
    oh-my-posh
    qrencode
    ranger
    socat
    sshpass
    uv
    vim
    watch
    wget
  ];

  # Dev boxes: set `my.workstation = true` for the host in flake.nix.
  workstation = with pkgs; [
    asciinema
    cmake
    devenv
    docker-client
    docker-compose
    ghostscript
    go
    golangci-lint
    himalaya
    k9s
    ko
    kubernetes-helm
    lazydocker
    lld
    meson
    minikube
    opencode
    poppler-utils
    signal-cli
    terraform
  ];
in
{
  options.my.workstation = lib.mkEnableOption "the dev/workstation package set";

  config.home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
    core ++ lib.optionals config.my.workstation workstation
  );
}
