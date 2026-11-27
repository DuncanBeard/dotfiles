# Steam Deck (SteamOS, user `deck`). Used by "deck@steamdeck" in ../flake.nix.
{ config, lib, pkgs, ... }:
let
  zsh = "${config.home.profileDirectory}/bin/zsh";
in
{
  # Konsole draws the prompt on the Deck itself, so it needs the Nerd Font.
  # Select "Hack Nerd Font" once in Konsole: Settings > Edit Current Profile >
  # Appearance.
  fonts.fontconfig.enable = true;
  home.packages = [ pkgs.nerd-fonts.hack ];

  # The login shell stays SteamOS's bash, so logins still work if /nix isn't
  # mounted (e.g. right after a SteamOS update). Top-level interactive bash
  # (Konsole, SSH) switches to Nix's zsh when it's there. Scripts, and a
  # `bash` typed inside zsh (SHLVL > 1), stay in bash.
  programs.bash.initExtra = lib.mkBefore ''
    if [[ $- == *i* && ''${SHLVL:-1} -le 1 && -x "${zsh}" ]]; then
      exec "${zsh}" -l
    fi
  '';
}
