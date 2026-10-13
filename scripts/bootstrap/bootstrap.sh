#!/bin/sh
# bbtux's environment on any Linux, macOS or WSL machine.
#   curl -fsSL https://raw.githubusercontent.com/bubuntux/den/main/scripts/bootstrap/bootstrap.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/bubuntux/den/main/scripts/bootstrap/bootstrap.sh | sh -s -- --container
set -eu

DEN_FLAKE="${DEN_FLAKE:-github:bubuntux/den}"
DEN_RAW="${DEN_RAW:-https://raw.githubusercontent.com/bubuntux/den/main/scripts/bootstrap}"
DEN_IMAGE="${DEN_IMAGE:-bbtux-env}"

SUBSTITUTERS="https://den.cachix.org https://helix.cachix.org https://nix-community.cachix.org https://devenv.cachix.org"
TRUSTED_PUBLIC_KEYS="den.cachix.org-1:1/SPrWvkgbW6kD/tfSN/a7WkoVajMEw1znID8ja+Z1M= helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs= devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr+cv0M+/mB6Sto4="

usage() {
  cat <<EOF
Usage: bootstrap.sh [--container]

  (default)     install Nix if missing, then activate the bbtux Home Manager
                environment for the current user
  --container   build and enter a docker/podman image with the environment,
                leaving this machine untouched

Environment:
  DEN_FLAKE   flake to build from (default: github:bubuntux/den)
  DEN_RAW     where to fetch the Containerfile from (default: this repo's scripts/bootstrap)
  DEN_IMAGE   image tag for --container (default: bbtux-env)
EOF
}

log() {
  printf '\033[1;34m==>\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

# Under `curl | sh` stdin is the script itself, so an interactive shell has to
# be pointed at the terminal.
exec_interactive() {
  if (: </dev/tty) 2>/dev/null; then
    exec "$@" </dev/tty
  fi
  log "No terminal attached; run it yourself: $*"
}

nix_cmd() {
  nix --extra-experimental-features 'nix-command flakes' "$@"
}

install_nix() {
  daemon_profile=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  if ! command -v nix >/dev/null 2>&1 && [ -r "$daemon_profile" ]; then
    # shellcheck disable=SC1090
    . "$daemon_profile"
  fi
  if command -v nix >/dev/null 2>&1; then
    log "Nix already installed: $(nix --version)"
    return
  fi

  log "Installing Nix (Determinate Systems installer)"
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm \
    --extra-conf "extra-substituters = $SUBSTITUTERS" \
    --extra-conf "extra-trusted-public-keys = $TRUSTED_PUBLIC_KEYS"
  # shellcheck disable=SC1090
  . "$daemon_profile"
}

activate_native() {
  install_nix

  USER="${USER:-$(id -un)}"
  export USER

  system="$(nix_cmd eval --impure --raw --expr builtins.currentSystem)"
  log "Building bbtux-anywhere-$system from $DEN_FLAKE"
  generation="$(nix_cmd build --impure --no-link --print-out-paths \
    --option extra-substituters "$SUBSTITUTERS" \
    --option extra-trusted-public-keys "$TRUSTED_PUBLIC_KEYS" \
    "$DEN_FLAKE#homeConfigurations.bbtux-anywhere-$system.activationPackage")"

  log "Activating (clobbered dotfiles are kept as *.bkp)"
  HOME_MANAGER_BACKUP_EXT=bkp "$generation/activate"

  log "Done"
  exec_interactive "$generation/home-path/bin/zsh" -l
}

run_container() {
  if command -v podman >/dev/null 2>&1; then
    engine=podman
    # Map the caller onto the image's uid 1000 so /work stays writable.
    userns="--userns=keep-id:uid=1000,gid=1000"
  elif command -v docker >/dev/null 2>&1; then
    engine=docker
    userns=""
  else
    die "--container needs podman or docker on PATH"
  fi

  context="$(mktemp -d)"
  trap 'rm -rf "$context"' EXIT
  log "Fetching Containerfile from $DEN_RAW"
  curl -fsSL "$DEN_RAW/Containerfile" -o "$context/Containerfile"

  log "Building $DEN_IMAGE with $engine (first build downloads a few GB)"
  "$engine" build --build-arg "DEN_FLAKE=$DEN_FLAKE" -t "$DEN_IMAGE" -f "$context/Containerfile" "$context"
  rm -rf "$context"
  trap - EXIT

  log "Entering $DEN_IMAGE; $PWD is mounted at /work"
  # shellcheck disable=SC2086
  exec_interactive "$engine" run -it --rm $userns -v "$PWD:/work" "$DEN_IMAGE"
}

case "${1:-}" in
"") activate_native ;;
--container) run_container ;;
-h | --help) usage ;;
*)
  usage >&2
  exit 2
  ;;
esac
