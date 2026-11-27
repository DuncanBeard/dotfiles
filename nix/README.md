# nix/

Nix config for macOS (nix-darwin) and Linux (standalone Home Manager).
Chezmoi ignores this directory (see `../.chezmoiignore`), so it behaves the
same whether `main` or `nix` is checked out.

## Branches

- `main`: chezmoi only. The stable path.
- `nix`: `main` + this directory. Keep it current with `git merge main`.
  Because it only adds files, merges don't conflict.

## Opting a machine in

```sh
git clone https://github.com/DuncanBeard/dotfiles.git ~/.local/share/chezmoi
git -C ~/.local/share/chezmoi switch nix      # the manual gate
~/.local/share/chezmoi/nix/bootstrap.sh       # --help for options
```

`bootstrap.sh` uses an existing checkout exactly as it is. It never pulls or
switches branches. Without a checkout it clones the `nix` branch itself (the
`curl` one-liner in its header).

## Day to day

| | |
|---|---|
| Apply (macOS) | `sudo darwin-rebuild switch --flake ~/.local/share/chezmoi/nix` |
| Apply (Linux) | `home-manager switch --flake ~/.local/share/chezmoi/nix#<config>` |
| Update pins | `nix flake update --flake ~/.local/share/chezmoi/nix`, then commit `flake.lock` |
| Roll back | `sudo darwin-rebuild --rollback` / `home-manager switch --rollback` |

Flakes only see files git knows about, so `git add` new files before switching.

## Never commit

Tokens (`.npmrc`), `gh/hosts.yml`, cloud and kube credentials, SSH keys, or the
SSH host list. This repo is public. Use sops-nix or `Include ~/.ssh/config.local`.
