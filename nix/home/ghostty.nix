# Ghostty settings shared by macOS (darwin.nix) and the Steam Deck (steamdeck.nix).
# Platform-specific settings (font size, keybinds, macOS options) live there.
{ ... }:
{
  programs.ghostty = {
    enable = true;
    # Ghostty injects its own shell integration.
    enableBashIntegration = false;
    enableZshIntegration = false;
    enableFishIntegration = false;
    installBatSyntax = false;

    # -> ~/.config/ghostty/config
    settings = {
      # Nerd Font build, so the prompt's icons render. Not the "Mono" variant:
      # Ghostty sizes Nerd Font icons itself, and Mono's are pre-shrunk.
      # (The old macOS value "Hack" matched no installed family, so Ghostty
      # had silently fallen back to its built-in default font.)
      font-family = "Hack Nerd Font";
      background-opacity = 1;
      split-divider-color = "#de8d5a";

      # SSH: automatic terminfo + env. The old macOS file set this twice and
      # the second line won, which left sudo integration off; same here.
      shell-integration-features = "ssh-env,ssh-terminfo";

      copy-on-select = "clipboard";
      clipboard-paste-protection = false;
    };
  };
}
