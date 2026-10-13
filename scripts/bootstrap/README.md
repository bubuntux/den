# bbtux anywhere

bbtux's shell environment on a machine that isn't mine — a borrowed laptop,
a test VM, a cloud instance or dev box — either installed into the current
account or inside a throwaway container.

It is the standalone Home Manager config `homeConfigurations.bbtux-anywhere-<system>`
(`modules/users/bbtux.nix`), built for whoever runs it:

| included | left out |
| --- | --- |
| zsh, starship, direnv, eza, screen | SSH config and keys |
| Helix (master) with its language servers | jj commit signing (the key is on zuko) |
| git and jj with my identity, gh, difftastic | secrets (sops) |
| Claude Code, devenv, ripgrep, fd, jq, … | the desktop (sway, waybar, firefox, theme) |
| nix settings and binary caches | auto-upgrade |

Everything is fetched from `github:bubuntux/den`, so it only sees what has been
pushed to `main`.

## Pick a route

| machine has | run |
| --- | --- |
| Linux, macOS (Apple silicon), WSL | [native](#native-linux-macos-wsl) |
| Docker or Podman, and I'd rather not touch it | [container](#container) |
| Windows | [Windows](#windows) |

Either way, expect a few minutes and a few GB of downloads on first run; everything
comes from binary caches, nothing compiles.

## Native (Linux, macOS, WSL)

```sh
curl -fsSL https://raw.githubusercontent.com/bubuntux/den/main/scripts/bootstrap/bootstrap.sh | sh
```

This:

1. installs Nix with the [Determinate Systems installer](https://github.com/DeterminateSystems/nix-installer)
   if it isn't there (asks for `sudo`), with my caches trusted;
1. builds `bbtux-anywhere-<system>` for the current `$USER`;
1. activates it, moving any dotfile it replaces to `<file>.bkp`;
1. drops into zsh.

The account's login shell is left alone; start a new session with `zsh -l`.

### Undo

```sh
sudo /nix/nix-installer uninstall
find ~ -lname '/nix/store/*' -delete
rm -rf ~/.nix-profile ~/.nix-defexpr ~/.local/state/nix ~/.local/state/home-manager ~/.cache/nix
for f in ~/.*.bkp; do mv "$f" "${f%.bkp}"; done
```

The first line only applies if the bootstrap installed Nix; on a machine that
already had it, skip it and run the rest.

## Container

Needs `podman` or `docker`; podman wins when both are present. Nothing is
installed on the host — the environment lives in an image called `bbtux-env`,
and the current directory is mounted at `/work`.

```sh
curl -fsSL https://raw.githubusercontent.com/bubuntux/den/main/scripts/bootstrap/bootstrap.sh | sh -s -- --container
```

The first build is the slow part (~5 min, ~10 GB image). After that, getting
back in is instant:

```sh
podman run -it --rm --userns=keep-id:uid=1000,gid=1000 -v "$PWD:/work" bbtux-env
docker run -it --rm -v "$PWD:/work" bbtux-env
```

`--rm` throws away anything outside `/work` on exit. Drop it and use
`podman start -ai <name>` to keep a container's state between sessions.

From a checkout, without the script:

```sh
podman build -t bbtux-env scripts/bootstrap/
```

### Undo

```sh
podman rmi bbtux-env    # or: docker rmi bbtux-env
```

## Windows

There is no native Windows Nix, so this goes through WSL or a container:

```powershell
irm https://raw.githubusercontent.com/bubuntux/den/main/scripts/bootstrap/bootstrap.ps1 | iex
```

- **WSL distro installed** → runs the [native](#native-linux-macos-wsl) route
  inside it.
- **no WSL, but Podman/Docker Desktop** → runs the [container](#container) route.
- **neither** → `wsl --install`, reboot, re-run.

To force the container even when WSL is there:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/bubuntux/den/main/scripts/bootstrap/bootstrap.ps1))) -Container
```

## Knobs

Both scripts read these from the environment:

| variable | default | for |
| --- | --- | --- |
| `DEN_FLAKE` | `github:bubuntux/den` | a branch (`github:bubuntux/den/<branch>`) or a checkout (`path:$PWD`, native only) |
| `DEN_RAW` | `https://raw.githubusercontent.com/bubuntux/den/main/scripts/bootstrap` | where the scripts fetch bootstrap.sh and the Containerfile from |
| `DEN_IMAGE` | `bbtux-env` | image tag |

## When it doesn't work

- **No systemd** (a plain container, old WSL): the Nix installer refuses. Use
  `--container`, or turn systemd on in WSL (`[boot] systemd=true` in
  `/etc/wsl.conf`, then `wsl --shutdown`).
- **Nix was already installed and I'm not a trusted user**: my caches are
  ignored with a warning, and Helix builds from source. Slow, not broken.
- **`/work` is not writable on Fedora/RHEL**: SELinux; add `:Z` to the
  volume (`-v "$PWD:/work:Z"`).
- **Intel Mac**: no config for `x86_64-darwin`; use the container route.
- **GUI apps from Nix**: the activation prints a `non-nixos-gpu-setup` hint.
  Nothing here needs a GPU, so ignore it.
