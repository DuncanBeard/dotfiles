# Steam Deck (SteamOS, user `deck`). Used by "deck@steamdeck" in ../flake.nix.
{ config, lib, pkgs, ... }:
let
  zsh = "${config.home.profileDirectory}/bin/zsh";
  fontSize = 10;  # KDE's default monospace size; Konsole and Ghostty both use it
  # KDE's default terminal. KDE starts it in the target folder (e.g. Dolphin's
  # "Open Terminal Here"), but a single-instance Ghostty would open the window
  # in its existing window's folder, so run a separate process that inherits it.
  terminal = "${config.home.profileDirectory}/bin/ghostty --gtk-single-instance=false --working-directory=inherit";
in
{
  imports = [ ./ghostty.nix ];

  # Konsole and Ghostty draw the prompt on the Deck itself, so it needs the
  # Nerd Font locally.
  fonts.fontconfig.enable = true;
  home.packages = [ pkgs.nerd-fonts.hack ];

  # Graphics drivers for Nix-built GUI apps (Ghostty). Needs a one-time root
  # setup: bootstrap.sh runs it, and if a later `hms` updates the drivers, it
  # prints the command to run again.
  targets.genericLinux.gpu.enable = true;

  # ------------------------------------------------------------- Ghostty
  # From nixpkgs. Shows up in the Desktop Mode menu after logging out and in.
  programs.ghostty.settings.font-size = fontSize;

  # ------------------------------------------------------------- Konsole
  # A "Nix" profile with the Nerd Font, made the default. Edit it here, not in
  # Konsole's settings dialog (the file is read-only).
  xdg.dataFile."konsole/Nix.profile".text = ''
    [Appearance]
    Font=Hack Nerd Font,${toString fontSize},-1,5,50,0,0,0,0,0

    [General]
    Name=Nix
    Parent=FALLBACK/
  '';

  # konsolerc and kdeglobals belong to KDE (it saves its own state there), so
  # set only these keys, with KDE's own config tool.
  home.activation.kdeDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kwc=""
    for k in /usr/bin/kwriteconfig6 /usr/bin/kwriteconfig5; do
      [ -x "$k" ] && { kwc="$k"; break; }
    done
    if [ -n "$kwc" ]; then
      # Konsole's default profile
      run "$kwc" --file konsolerc --group "Desktop Entry" --key DefaultProfile Nix.profile
      # KDE's default terminal (Dolphin's "Open Terminal Here", etc.).
      # TerminalService would take precedence over TerminalApplication.
      run "$kwc" --file kdeglobals --group General --key TerminalApplication "${terminal}"
      run "$kwc" --file kdeglobals --group General --key TerminalService --delete
    else
      warnEcho "kwriteconfig not found; set Konsole's profile and KDE's default terminal manually"
    fi
  '';

  # ------------------------------------------------------------ shell
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
