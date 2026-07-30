# den

[![NixOS](https://img.shields.io/badge/NixOS-26.05-blue?logo=nixos)](https://nixos.org)
[![Flake](https://img.shields.io/badge/Nix-Flake-informational?logo=nixos)](https://nixos.wiki/wiki/Flakes)
[![Home Manager](https://img.shields.io/badge/Home%20Manager-enabled-blue?logo=nixos)](https://github.com/nix-community/home-manager)
[![CI](https://github.com/bubuntux/den/actions/workflows/ci.yml/badge.svg)](https://github.com/bubuntux/den/actions/workflows/ci.yml)

Personal NixOS configuration managed as a Nix Flake, using a modular
architecture powered by [flake-parts](https://flake.parts/) and the
[dendritic pattern](https://github.com/mightyiam/dendritic).

## Overview

Every `.nix` file in this repository is a
[flake-parts](https://github.com/hercules-ci/flake-parts) module publishing
one or more modules under `flake.modules.nixos.*` / `flake.modules.homeManager.*`.
Files are auto-discovered via
[import-tree](https://github.com/vic/import-tree) and
[flake-file](https://github.com/vic/flake-file), so there is no manual
import list to maintain — just add a file and it becomes part of the
configuration.

Several files may also contribute to the *same* module name, which is how
each host is assembled from small pieces:
`hosts/zuko/{default,hardware,monitors}.nix` all define
`flake.modules.nixos.zuko`.

## Hosts

Hosts are named after Avatar: The Last Airbender characters.

| Host | Hardware | Role |
| --- | --- | --- |
| **zuko** | Dell Precision 5680 (Intel/NVIDIA) | Primary dev laptop — Sway, gaming, work container, development |
| **katara** | AMD laptop | Family computer |
| **appa** | Intel Pentium Silver J5040 | NAS — media server, reverse proxy, backups |

## Module Hierarchy

```
Features ──→ Bundles ──→ Profiles ──→ Hosts
    │                     ↑   ↑          ↑
    └─────────────────────┘   │          │
                            Users     Hardware
```

Users are imported by profiles, not by hosts — a role knows who operates the
machine. Profiles may compose other profiles, a host may import as many
profiles as it needs, and a host may add a feature that only makes sense on
that one machine (zuko's `droidcam`, `cachix-push`).

- **`modules/features/`** — Software and service configurations
- **`modules/bundles/`** — Reusable aggregates: `bundle-base` (container-safe
  foundation), `bundle-host` (adds what a real machine needs),
  `bundle-desktop`
- **`modules/profiles/`** — Whole-machine **roles** (`workstation`, `nas`,
  `family`) and composable **capabilities** (`laptop`, `developer`, `gaming`,
  `work`); a role is just a named set of capabilities that more than one host
  wanted
- **`modules/hosts/`** — Per-machine configuration: the profiles it needs plus
  hardware
- **`modules/users/`** — User account definitions
- **`modules/hardware/`** — Device and hardware configurations
- **`modules/core/`** — Infrastructure glue, including the flake checks

## Desktop

Desktop environment and login manager are chosen independently through
`den.desktop`, so a host can install several environments at once and let each
user pick one at the greeter. Which environments are installed and which
environment each user gets are contributed additively, so several profiles can
each ask for one; the greeter and the preselected session are whole-machine
settings and belong to the host.

Each environment lives under `modules/features/desktop/session/` — one file, or
a directory when it brings companion pieces of its own (`session/sway/` carries
waybar, kanshi and dictation, none of which mean anything under GNOME) — and
each login manager is one file under `modules/features/desktop/login/`. Invalid
combinations are refused at build time by assertions, which the
`desktop-rejects` flake check keeps honest.

## Usage

### NixOS Host (fresh install)

```bash
# From a NixOS live ISO or existing install
sudo nixos-rebuild switch --flake github:bubuntux/den#<hostname>

# Or from a local clone
sudo nixos-rebuild switch --flake .
```

### Home Manager (non-NixOS)

Install the developer environment on any Linux distro with Nix installed.

```bash
# 1. Install Nix (if not already)
curl -L https://nixos.org/nix/install | sh -s -- --daemon

# 2. Enable flakes
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# 3. Add yourself to trusted-users (needed for custom substituters)
echo "trusted-users = root $(whoami)" | sudo tee -a /etc/nix/nix.conf
sudo systemctl restart nix-daemon

# 4. Apply the home configuration
nix run home-manager/master -- switch -b bkp --flake github:bubuntux/den#<user>
```

Subsequent updates:

```bash
home-manager switch --flake github:bubuntux/den#<user> --refresh
```

### Development

```bash
# Test a host in a QEMU VM
nix run .#<hostname>-vm

# Build a host without applying it
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel

# Validate, format, and update
nix flake check
nix fmt
nix flake update
```

`nix flake check` is evaluation-only — formatting plus four checks that verify
the desktop combinations, that invalid ones are refused, that no unexpected
systemd directives appear on the units this repo configures, and that the media
service registry generates what it claims. Host builds are left to CI, which
builds each host in its own job.
