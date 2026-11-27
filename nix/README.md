# nix/

Nix config for macOS (nix-darwin + Home Manager) and Linux (standalone Home
Manager). Chezmoi ignores this directory (see `../.chezmoiignore`).

```
flake.nix          inputs; darwinConfigurations; homeConfigurations (mkHome)
darwin.nix         macOS system: Homebrew brews/casks, fonts, Touch ID, HM wiring
home/common.nix    every machine: git, tmux, ssh, first-switch takeover
home/shell.nix     zsh (oh-my-zsh + oh-my-posh), bash, readline
home/bash/prompt.sh  bash prompt, history, nvm (plain shell, no Nix escaping)
home/packages.nix  CLI packages (Linux only for now); `my.workstation` adds dev tools
home/darwin.nix    macOS user bits: Apple git, brew shellenv, 1Password agent, Ghostty, mac aliases
home/ghostty.nix   Ghostty settings shared by macOS and the Steam Deck
home/steamdeck.nix Steam Deck: Ghostty, Konsole profile, Nerd Font, GPU drivers, bash -> zsh
home/linux.nix     non-NixOS fixes, `home-manager` CLI, weekly GC
bootstrap.sh       new-machine setup (see below)
```

## Branches

- `main`: chezmoi only. The stable path.
- `nix`: `main` plus this directory, and one block in `.chezmoiignore`.
  On macOS/Linux, chezmoi stops managing `.zshrc`, `.bash_profile`,
  `.inputrc`, `.gitconfig` and `.ssh/config`, because Home Manager owns them.
  Everything else (oh-my-posh theme, Logseq, Claude, herdr, Windows) stays
  with chezmoi. Keep the branch current with `git merge main`.

## Opting a machine in

The repo lives at `~/.dotfiles` on every machine.

```sh
git clone https://github.com/DuncanBeard/dotfiles.git ~/.dotfiles
git -C ~/.dotfiles switch nix      # the manual gate
~/.dotfiles/nix/bootstrap.sh       # --help for options
```

`bootstrap.sh` uses an existing checkout exactly as it is. It never pulls or
switches branches.

Only if the machine also uses chezmoi, point chezmoi's default folder at the
repo. Move aside any old checkout there first:

```sh
ln -s ~/.dotfiles ~/.local/share/chezmoi
```

### What the first switch does to existing files

| File | Becomes |
|---|---|
| `.zshrc` `.zprofile` `.bash_profile` `.bashrc` `.profile` `.inputrc` `.config/git/ignore` | renamed `*.pre-hm`; HM's version is linked in its place |
| `.gitconfig`, `.tmux.conf` | renamed `*.pre-hm` (they'd shadow HM's `~/.config/...` files) |
| `.ssh/config` | renamed `.ssh/config.local`; HM's `.ssh/config` Includes it, so all hosts keep working |
| macOS: Ghostty's `config` and `config.ghostty` in `~/Library/Application Support/com.mitchellh.ghostty/` | renamed `*.pre-hm` (Ghostty would load them on top of HM's `~/.config/ghostty/config`) |

Nothing is deleted. To undo on macOS, switch back to the old flake, restore the
`*.pre-hm` files, and move `config.local` back:

```sh
sudo darwin-rebuild switch --flake ~/.config/nix   # the pre-HM system
for f in ~/.*.pre-hm ~/.config/git/ignore.pre-hm; do mv "$f" "${f%.pre-hm}"; done
mv ~/.ssh/config.local ~/.ssh/config
G=~/Library/Application\ Support/com.mitchellh.ghostty; for f in "$G"/*.pre-hm; do mv "$f" "${f%.pre-hm}"; done
```

### This Mac specifically

Already set up: the repo is at `~/.dotfiles` on `nix`, and
`~/.local/share/chezmoi` is a symlink to it. To opt in:

```sh
sudo darwin-rebuild switch --flake ~/.dotfiles/nix
```

`~/.config/nix` (the old flake) can be deleted once you're happy.

## Steam Deck

Config `deck@steamdeck` (`home/steamdeck.nix`). Nix lives in `/home/nix` (the
installer's Steam Deck mode), so it survives SteamOS updates. Game Mode is
unaffected. The Deck gets standard Nix, not Determinate Nix: the installer puts
Determinate's daemon in `/usr/local/bin`, which is read-only on SteamOS.

1. Desktop Mode, then Konsole. SteamOS ships without a password, and the
   installer needs `sudo`:
   ```sh
   passwd
   sudo systemctl enable --now sshd   # optional: do the rest over SSH from the Mac
   ```
2. In Konsole, or `ssh deck@steamdeck` from the Mac:
   ```sh
   git clone https://github.com/DuncanBeard/dotfiles.git ~/.dotfiles
   git -C ~/.dotfiles switch nix
   ~/.dotfiles/nix/bootstrap.sh
   ```
   With no `git` on the system, use
   `bash <(curl -fsSL https://raw.githubusercontent.com/DuncanBeard/dotfiles/nix/nix/bootstrap.sh)`
   instead; it clones the `nix` branch using Nix's git.
3. Log out of Desktop Mode and back in (or reboot) so the menu picks up Ghostty.

What you get:
- Konsole: a "Nix" profile (Hack Nerd Font, 10 pt) set as the default. Change
  it in `steamdeck.nix`; the profile file is read-only to Konsole.
- Ghostty from nixpkgs, sharing `home/ghostty.nix` with the Mac, and set as
  KDE's default terminal (Dolphin's "Open Terminal Here" etc.). Ctrl+Alt+T is
  still bound to Konsole.
- GPU drivers for Nix GUI apps (`/run/opengl-driver`). bootstrap.sh does the
  one-time root setup. If a later `hms` updates the drivers, it prints the
  `sudo ... non-nixos-gpu-setup` command to run again.
- The login shell stays SteamOS's bash. Interactive bash (Konsole, SSH)
  switches to zsh, and stays in bash if `/nix` is ever missing.

Renamed the Deck? Pass `--config deck@steamdeck`. Remove Nix entirely with
`/nix/nix-installer uninstall`.

## Day to day

| | |
|---|---|
| Apply | `hms` (alias: darwin-rebuild on macOS, home-manager on Linux) |
| Update pins | `nix flake update --flake ~/.dotfiles/nix`, then commit `flake.lock` |
| Roll back | `sudo darwin-rebuild --rollback` / `home-manager switch --rollback` |
| Add a Linux host | add it to `hosts` in `flake.nix` (`my.workstation = true` for dev tools) |

Flakes only see files git knows about, so `git add` new files before switching.

## Never commit

Tokens (`.npmrc`), `gh/hosts.yml`, cloud and kube credentials, SSH keys, or the
SSH host list (`~/.ssh/config.local`). This repo is public.

## Not migrated yet

VS Code, Zed, LaunchAgents, `system.defaults`, Mac App Store apps.
On macOS, CLI tools still come from Homebrew, because the Hermes and OpenClaw
LaunchAgents hard-code `/opt/homebrew`.
