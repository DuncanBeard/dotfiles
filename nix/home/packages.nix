# CLI packages from nixpkgs. The lists mirror the Mac's `brew leaves` where
# that makes sense. On macOS, tools that the Hermes and OpenClaw LaunchAgents
# run stay in Homebrew (../darwin.nix): those agents' PATH has /opt/homebrew/bin
# and no Nix directories.
{ config, lib, pkgs, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;

  # Everywhere, including small servers and Pis.
  core = with pkgs; [
    doggo
    iperf3
    moreutils
    ncdu
    nmap
    oh-my-posh
    qrencode
    ranger
    socat
    watch
    wget
  ] ++ lib.optionals isLinux [
    gh       # macOS: Homebrew (Hermes)
    neovim   # macOS: system-wide, ../darwin.nix
    sshpass  # macOS: Homebrew (Hermes)
    uv       # macOS: self-updating install in ~/.local/bin
    vim      # macOS: system-wide, ../darwin.nix
  ];

  # Dev boxes: set `my.workstation = true` for the host in flake.nix.
  workstation = with pkgs; [
    asciinema
    devenv
    golangci-lint
    k9s
    ko
    kubernetes-helm
    lazydocker
    lld
    meson
    minikube
    ninja  # meson's backend
  ] ++ lib.optionals isLinux [
    # macOS: Homebrew. Hermes runs all of these, and Homebrew's cmake also
    # finds Homebrew's libraries (sdl2_image etc.), which Nix's cmake wouldn't.
    cmake
    docker-client
    docker-compose
    ghostscript
    go
    himalaya
    opencode
    poppler-utils
    signal-cli
  ];

  # macOS only.
  darwin = with pkgs; [
    chezmoi
    czkawka
    libimobiledevice
    libirecovery
    libnfc
    xcodegen
  ];
in
{
  options.my.workstation = lib.mkEnableOption "the dev/workstation package set";

  config.home.packages =
    core
    ++ lib.optionals config.my.workstation workstation
    ++ lib.optionals isDarwin darwin;
}
