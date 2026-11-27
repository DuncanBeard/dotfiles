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
home/darwin.nix    macOS user bits: Apple git, brew shellenv, 1Password agent, mac aliases
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

```sh
git clone https://github.com/DuncanBeard/dotfiles.git ~/.local/share/chezmoi
git -C ~/.local/share/chezmoi switch nix      # the manual gate
~/.local/share/chezmoi/nix/bootstrap.sh       # --help for options
```

`bootstrap.sh` uses an existing checkout exactly as it is. It never pulls or
switches branches.

### What the first switch does to existing files

| File | Becomes |
|---|---|
| `.zshrc` `.zprofile` `.bash_profile` `.bashrc` `.profile` `.inputrc` `.config/git/ignore` | renamed `*.pre-hm`; HM's version is linked in its place |
| `.gitconfig`, `.tmux.conf` | renamed `*.pre-hm` (they'd shadow HM's `~/.config/...` files) |
| `.ssh/config` | renamed `.ssh/config.local`; HM's `.ssh/config` Includes it, so all hosts keep working |

Nothing is deleted. To undo on macOS, switch back to the old flake, restore the
`*.pre-hm` files, and move `config.local` back:

```sh
sudo darwin-rebuild switch --flake ~/.config/nix   # the pre-HM system
for f in ~/.*.pre-hm ~/.config/git/ignore.pre-hm; do mv "$f" "${f%.pre-hm}"; done
mv ~/.ssh/config.local ~/.ssh/config
```

### This Mac specifically

The local chezmoi checkout is behind `main` and has uncommitted changes.
Sort that out first, and **don't commit `private_dot_ssh/`** (public repo).
Then:

```sh
cd ~/.local/share/chezmoi && git pull && git switch nix
sudo darwin-rebuild switch --flake ~/.local/share/chezmoi/nix
```

`~/.config/nix` (the old flake) can be deleted once you're happy.

## Day to day

| | |
|---|---|
| Apply | `hms` (alias: darwin-rebuild on macOS, home-manager on Linux) |
| Update pins | `nix flake update --flake ~/.local/share/chezmoi/nix`, then commit `flake.lock` |
| Roll back | `sudo darwin-rebuild --rollback` / `home-manager switch --rollback` |
| Add a Linux host | add it to `hosts` in `flake.nix` (`my.workstation = true` for dev tools) |

Flakes only see files git knows about, so `git add` new files before switching.

## Never commit

Tokens (`.npmrc`), `gh/hosts.yml`, cloud and kube credentials, SSH keys, or the
SSH host list (`~/.ssh/config.local`). This repo is public.

## Not migrated yet

Ghostty, VS Code, Zed, LaunchAgents, `system.defaults`, Mac App Store apps.
On macOS, CLI tools still come from Homebrew, because the Hermes and OpenClaw
LaunchAgents hard-code `/opt/homebrew`.
