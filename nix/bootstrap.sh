#!/usr/bin/env bash
# bootstrap.sh: set up a machine from the nix/ flake in github.com/DuncanBeard/dotfiles
#
# The `nix` branch is main (chezmoi) + this nix/ directory. Opting in is manual:
#   git clone https://github.com/DuncanBeard/dotfiles.git ~/.dotfiles
#   git -C ~/.dotfiles switch nix     # <- your gate
#   ~/.dotfiles/nix/bootstrap.sh
# An existing checkout is used exactly as-is: the script never pulls or switches.
#
# Without a checkout it clones $BRANCH itself:
#   bash <(curl -fsSL https://raw.githubusercontent.com/DuncanBeard/dotfiles/nix/nix/bootstrap.sh)
#
# From your Mac, run your *local* (possibly unpushed) copy on a remote box:
#   ./nix/bootstrap.sh --remote kali-pi
#
# Safe to re-run: every step checks before acting.
#
# Steps:
#   1. OS prerequisites (Linux: curl, git, zsh via distro; macOS: Xcode CLT)
#   2. Determinate Nix
#   3. Mark you as a trusted Nix user (devenv/cachix substituters)
#   4. Use the existing checkout, or clone $BRANCH to $DEST
#   5. Activate $DEST/nix: home-manager (Linux) or nix-darwin (macOS)
#   6. Linux: login shell -> zsh, optional systemd linger
#   7. Print the remaining manual steps (secrets / logins)

set -euo pipefail

REPO="${REPO:-https://github.com/DuncanBeard/dotfiles.git}"
PUSH_URL="${PUSH_URL:-git@github.com:DuncanBeard/dotfiles.git}"
BRANCH="${BRANCH:-nix}"     # only used when cloning fresh
DEST="${DEST:-}"            # repo checkout; default: the one this script is in,
                            # else ~/.dotfiles
FLAKE_SUBDIR=nix
FLAKE=""                    # set by resolve_dest: $DEST/$FLAKE_SUBDIR
CONFIG="${CONFIG:-}"        # force a flake config name; default is auto-detected
HM_REF="${HM_REF:-master}"  # home-manager ref used only for the first switch
LINGER=0
CHSH=1
TRUST=1

NIX_BIN=/nix/var/nix/profiles/default/bin/nix
# unset in Docker; exported because home-manager and its activation read $USER
export USER="${USER:-$(id -un)}"
OS="$(uname -s)"
OS_RELEASE="${OS_RELEASE:-/etc/os-release}"  # overridable for tests

# SteamOS (Steam Deck): read-only root, so no distro packages and no chsh.
# The installer picks its steam-deck mode itself (/nix lives in /home/nix).
is_steamos() { grep -qE '^ID="?steamos"?$' "$OS_RELEASE" 2>/dev/null; }

usage() {
  cat <<EOF
Usage: bootstrap.sh [options]

  --remote HOST    Copy this script to HOST and run it there (ssh -tA)
  --config NAME    Flake config to activate (default: auto-detect)
  --branch NAME    Repo branch (default: $BRANCH)
  --dest DIR       Repo checkout (default: this script's checkout,
                   else ~/.dotfiles)
  --linger         Linux: enable systemd linger so user services run logged-out
  --no-chsh        Linux: don't change the login shell
  --no-trust       Don't add you to Nix trusted-users
  -h, --help       Show this help

Env overrides: REPO, PUSH_URL, BRANCH, DEST, CONFIG, HM_REF
EOF
}

c_bold=$'\e[1m'; c_blue=$'\e[34m'; c_yel=$'\e[33m'; c_red=$'\e[31m'; c_off=$'\e[0m'
[ -t 1 ] || { c_bold=; c_blue=; c_yel=; c_red=; c_off=; }
step() { printf '\n%s==>%s %s%s%s\n' "$c_blue" "$c_off" "$c_bold" "$*" "$c_off"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '%swarning:%s %s\n' "$c_yel" "$c_off" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$c_red" "$c_off" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- remote mode
run_remote() {
  local host="$1"; shift
  [ -f "$0" ] || die "--remote needs to be run from a file, not a pipe"
  step "Copying bootstrap.sh to $host"
  scp -q "$0" "$host:/tmp/bootstrap.sh"
  local env_args
  env_args="$(printf '%q ' "REPO=$REPO" "PUSH_URL=$PUSH_URL" "BRANCH=$BRANCH" "HM_REF=$HM_REF")"
  [ -n "$CONFIG" ] && env_args+="$(printf '%q ' "CONFIG=$CONFIG")"
  # -t: tty for sudo prompts; -A: forward your 1Password SSH agent
  exec ssh -tA "$host" "env $env_args bash /tmp/bootstrap.sh $(printf '%q ' "$@")"
}

# ---------------------------------------------------------------------- sudo
SUDO=""
setup_sudo() {
  [ "$(id -u)" -eq 0 ] && return
  have sudo || die "need root or sudo"
  SUDO="sudo"
  info "sudo may prompt for your password once"
  if ! sudo -v; then
    is_steamos && die "sudo failed. SteamOS has no password for deck by default: run 'passwd' first"
    die "sudo failed"
  fi
  # keep the sudo timestamp fresh while Nix installs (can take minutes)
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done ) 2>/dev/null &
}

# ------------------------------------------------------------ 1. prerequisites
install_prereqs_linux() {
  if is_steamos; then
    step "SteamOS: skipping distro packages (read-only system)"
    have curl || die "curl is missing"
    have git || info "no system git; Nix's git will be used"
    return
  fi
  step "Distro prerequisites (curl, git, zsh)"
  if have curl && have git && have zsh; then info "already installed"; return; fi
  if   have apt-get; then $SUDO apt-get update -qq
                          $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates git zsh xz-utils
  elif have dnf;     then $SUDO dnf install -y -q curl git zsh
  elif have pacman;  then $SUDO pacman -Sy --needed --noconfirm curl git zsh
  elif have zypper;  then $SUDO zypper -n -q install curl git zsh
  else die "unknown package manager; install curl, git and zsh, then re-run"
  fi
}

install_prereqs_darwin() {
  step "Xcode Command Line Tools"
  if xcode-select -p >/dev/null 2>&1; then info "already installed"; return; fi
  xcode-select --install >/dev/null 2>&1 || true
  info "Finish the Command Line Tools installer dialog; waiting..."
  until xcode-select -p >/dev/null 2>&1; do sleep 5; done
}

# ------------------------------------------------------------------ 2. Nix
install_nix() {
  step "Determinate Nix"
  if [ -x "$NIX_BIN" ]; then
    info "already installed: $("$NIX_BIN" --version)"
  else
    local args=(install)
    if [ "$OS" = Linux ] && [ ! -d /run/systemd/system ]; then
      # containers / WSL without systemd: no daemon, so it only works as root
      [ "$(id -u)" -eq 0 ] || die "no systemd: run as root, or enable systemd (WSL: [boot] systemd=true in /etc/wsl.conf)"
      warn "no systemd detected; installing without a daemon (--init none)"
      args=(install linux --init none --extra-conf "sandbox = false")
    fi
    curl --proto '=https' --tlsv1.2 -sSfL https://install.determinate.systems/nix \
      | sh -s -- "${args[@]}" --no-confirm
  fi
  # load nix into this shell (profile scripts aren't `set -u` clean)
  set +u
  for f in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
           /nix/var/nix/profiles/default/etc/profile.d/nix.sh; do
    # shellcheck disable=SC1090
    [ -r "$f" ] && { . "$f"; break; }
  done
  set -u
  export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"
  have nix || die "nix not on PATH after install"
}

# --------------------------------------------------------- 3. trusted user
trust_user() {
  [ "$TRUST" = 1 ] && [ "$(id -u)" -ne 0 ] || return 0
  step "Nix trusted-users"
  local conf=/etc/nix/nix.custom.conf
  # Determinate includes nix.custom.conf; fall back to nix.conf for other installs
  grep -q 'nix.custom.conf' /etc/nix/nix.conf 2>/dev/null || conf=/etc/nix/nix.conf
  if grep -E "^[[:space:]]*(extra-)?trusted-users[[:space:]]*=" "$conf" 2>/dev/null | grep -qw -- "$USER"; then
    info "$USER already trusted"; return
  fi
  echo "extra-trusted-users = $USER" | $SUDO tee -a "$conf" >/dev/null
  if [ "$OS" = Darwin ]; then
    $SUDO launchctl kickstart -k system/systems.determinate.nix-daemon 2>/dev/null \
      || $SUDO launchctl kickstart -k system/org.nixos.nix-daemon 2>/dev/null \
      || warn "couldn't restart nix-daemon; reboot or restart it manually"
  elif [ -d /run/systemd/system ]; then
    $SUDO systemctl restart nix-daemon || warn "couldn't restart nix-daemon"
  fi
  info "added $USER to $conf"
}

# ----------------------------------------------------------------- 4. repo
resolve_dest() {
  if [ -z "$DEST" ] && [ -f "$0" ] && have git; then
    # running from a checkout (the manual opt-in path): use that checkout
    local top
    top="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$top" ] && [ -f "$top/$FLAKE_SUBDIR/flake.nix" ] && DEST="$top"
  fi
  DEST="${DEST:-$HOME/.dotfiles}"
  FLAKE="$DEST/$FLAKE_SUBDIR"
}

# git, or Nix's git where the system has none (SteamOS). Needs Nix, so only
# from sync_repo onwards.
run_git() {
  if have git; then git "$@"; else nix run nixpkgs#git -- "$@"; fi
}

sync_repo() {
  step "Config repo: $DEST"
  if [ -e "$DEST/.git" ]; then  # -e: worktrees have a .git *file*
    # Existing checkout: what's checked out is your decision. No pull, no switch.
    local branch
    branch="$(run_git -C "$DEST" symbolic-ref --short -q HEAD || echo "detached HEAD")"
    info "using checkout as-is: $branch @ $(run_git -C "$DEST" log -1 --format='%h %s')"
    [ -f "$FLAKE/flake.nix" ] \
      || die "no $FLAKE_SUBDIR/flake.nix on '$branch'. To opt in: git -C $DEST switch $BRANCH"
    run_git -C "$DEST" diff --quiet HEAD -- "$FLAKE_SUBDIR" \
      || warn "uncommitted changes in $FLAKE_SUBDIR/ will be used"
    [ -z "$(run_git -C "$DEST" ls-files --others --exclude-standard -- "$FLAKE_SUBDIR")" ] \
      || warn "untracked files in $FLAKE_SUBDIR/ are invisible to the flake (git add them)"
  elif [ -e "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
    die "$DEST exists and isn't a git checkout; move it aside and re-run"
  else
    info "cloning $REPO ($BRANCH)"
    mkdir -p "$(dirname "$DEST")"
    run_git clone --quiet --branch "$BRANCH" "$REPO" "$DEST"
    # pull anonymously over https, push over ssh (1Password agent)
    run_git -C "$DEST" remote set-url --push origin "$PUSH_URL"
    [ -f "$FLAKE/flake.nix" ] || die "no $FLAKE_SUBDIR/flake.nix on branch $BRANCH"
    info "at $(run_git -C "$DEST" log -1 --format='%h %s')"
  fi
}

# ------------------------------------------------------------- 5. activate
pick_config() {  # pick_config <flake output> <candidate names...>
  local out="$1"; shift
  local names
  info "evaluating $out (first run downloads nixpkgs)..." >&2
  names="$(nix eval --raw "$FLAKE#$out" \
    --apply 'x: builtins.concatStringsSep "\n" (builtins.attrNames x)')" \
    || die "couldn't evaluate $FLAKE#$out (see error above)"
  for c in "$@"; do
    [ -n "$c" ] && printf '%s\n' "$names" | grep -qxF -- "$c" && { echo "$c"; return; }
  done
  die "no $out entry matching: $*
    available: $(echo $names)
    re-run with --config NAME, or add this machine to the flake"
}

activate_linux() {
  local arch; arch="$(uname -m)"
  case "$arch" in armv7l|armv6l) warn "32-bit ARM has almost no binary cache; expect long builds (use a 64-bit OS)";; esac
  local host; host="$(uname -n)"
  local cfg
  if [ -n "$CONFIG" ]; then cfg="$CONFIG"
  else cfg="$(pick_config homeConfigurations "$USER@${host%%.*}" "$USER@$host" "$USER@$arch-linux")"
  fi
  step "home-manager switch ($cfg)"
  nix run "github:nix-community/home-manager/$HM_REF" -- \
    switch -b pre-hm --flake "$FLAKE#$cfg"
}

activate_darwin() {
  local cfg
  if [ -n "$CONFIG" ]; then cfg="$CONFIG"
  else cfg="$(pick_config darwinConfigurations "$(scutil --get LocalHostName)")"
  fi
  # First activation: nix-darwin refuses to replace stock /etc shell files and
  # tells you to rename them to *.before-nix-darwin. Do that for it.
  if [ ! -e /run/current-system ]; then
    for f in /etc/zshrc /etc/zprofile /etc/zshenv /etc/bashrc; do
      if [ -f "$f" ] && [ ! -L "$f" ] && [ ! -e "$f.before-nix-darwin" ]; then
        $SUDO mv "$f" "$f.before-nix-darwin" && info "moved $f -> $f.before-nix-darwin"
      fi
    done
  fi
  step "darwin-rebuild switch ($cfg)"
  # sudo resets PATH; make sure darwin-rebuild can find nix
  $SUDO env PATH="/nix/var/nix/profiles/default/bin:$PATH" \
    "$NIX_BIN" run github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
    switch --flake "$FLAKE#$cfg"
}

# --------------------------------------------------------- 6. linux extras
set_login_shell() {
  [ "$CHSH" = 1 ] || return 0
  step "Login shell"
  if is_steamos; then
    # Keep SteamOS's bash so logins work even if /nix isn't mounted;
    # interactive bash switches to zsh instead (home/steamdeck.nix).
    info "SteamOS: keeping bash as the login shell (it hands off to zsh)"
    return
  fi
  local current zsh_path
  current="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || true)"
  case "$current" in */zsh) info "already $current"; return;; esac
  # prefer distro zsh so you can still log in if /nix ever breaks
  for p in /usr/bin/zsh /bin/zsh "$HOME/.nix-profile/bin/zsh"; do
    [ -x "$p" ] && { zsh_path="$p"; break; }
  done
  [ -n "${zsh_path:-}" ] || { warn "zsh not found; skipping"; return; }
  grep -qx "$zsh_path" /etc/shells || echo "$zsh_path" | $SUDO tee -a /etc/shells >/dev/null
  if have chsh; then $SUDO chsh -s "$zsh_path" "$USER"
  elif have usermod; then $SUDO usermod -s "$zsh_path" "$USER"
  else warn "no chsh/usermod; set your shell to $zsh_path manually"; return
  fi
  info "login shell -> $zsh_path"
}

enable_linger() {
  [ "$LINGER" = 1 ] || return 0
  step "systemd linger"
  if have loginctl; then $SUDO loginctl enable-linger "$USER" && info "enabled for $USER"
  else warn "loginctl not available"
  fi
}

# ------------------------------------------------------------------- 7. done
next_steps() {
  step "Done. Remaining manual steps:"
  cat <<EOF
    - start a fresh shell:         exec zsh -l
    - GitHub CLI:                  gh auth login
    - cloud/k8s (if needed here):  az login / aws configure sso / copy kubeconfigs
    - secrets (if using sops-nix): put your age key in ~/.config/sops/age/keys.txt, re-run
    - later updates:               git -C $DEST pull && hms
EOF
}

# ------------------------------------------------------------------- main
main() {
  local remote=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --remote)   remote="${2:?--remote needs a host}"; shift 2;;
      --config)   CONFIG="${2:?}"; shift 2;;
      --branch)   BRANCH="${2:?}"; shift 2;;
      --dest)     DEST="${2:?}"; shift 2;;
      --linger)   LINGER=1; shift;;
      --no-chsh)  CHSH=0; shift;;
      --no-trust) TRUST=0; shift;;
      -h|--help)  usage; exit 0;;
      *) usage >&2; die "unknown option: $1";;
    esac
  done

  if [ -n "$remote" ]; then
    local fwd=()
    [ -n "$CONFIG" ]   && fwd+=(--config "$CONFIG")
    [ "$LINGER" = 1 ]  && fwd+=(--linger)
    [ "$CHSH" = 0 ]    && fwd+=(--no-chsh)
    [ "$TRUST" = 0 ]   && fwd+=(--no-trust)
    # ${a[@]+...}: empty arrays trip `set -u` on macOS's bash 3.2
    run_remote "$remote" --branch "$BRANCH" ${fwd[@]+"${fwd[@]}"}
  fi

  case "$OS" in Linux|Darwin) ;; *) die "unsupported OS: $OS";; esac
  resolve_dest
  printf '%sBootstrapping %s@%s (%s) from %s%s\n' "$c_bold" "$USER" "$(uname -n)" "$OS" "$FLAKE" "$c_off"

  setup_sudo
  if [ "$OS" = Linux ]; then install_prereqs_linux; else install_prereqs_darwin; fi
  install_nix
  trust_user
  sync_repo
  if [ "$OS" = Linux ]; then
    activate_linux
    set_login_shell
    enable_linger
  else
    activate_darwin
  fi
  next_steps
}

# Wrapped in main so a truncated `curl` download can't run half a script.
main "$@"
