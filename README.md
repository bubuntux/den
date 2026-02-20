# den

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue?logo=nixos)](https://nixos.org)
[![Flake](https://img.shields.io/badge/Nix-Flake-informational?logo=nixos)](https://nixos.wiki/wiki/Flakes)
[![Home Manager](https://img.shields.io/badge/Home%20Manager-enabled-blue?logo=nixos)](https://github.com/nix-community/home-manager)
[![CI](https://github.com/bubuntux/den/actions/workflows/ci.yml/badge.svg)](https://github.com/bubuntux/den/actions/workflows/ci.yml)

Personal NixOS configuration managed as a Nix Flake, using a modular
architecture powered by [flake-parts](https://flake.parts/) and the
[dendritic pattern](https://github.com/mightyiam/dendritic).

## Overview

Every `.nix` file in this repository is a self-contained
[flake-parts](https://github.com/hercules-ci/flake-parts) module
implementing a single feature. Files are auto-discovered via
[import-tree](https://github.com/vic/import-tree) and
[flake-file](https://github.com/vic/flake-file), so there is no manual
import list to maintain — just add a file and it becomes part of the
configuration.

## Hosts

Hosts are named after Avatar: The Last Airbender characters.

| Host | Hardware | Role |
| --- | --- | --- |
| **zuko** | Dell Precision 5680 (Intel/NVIDIA) | Primary dev laptop — Sway, gaming, work container, development |
| **katara** | AMD laptop | Family laptop — GNOME desktop |
| **appa** | — | Placeholder |
| **momo** | — | Placeholder |

## Module Hierarchy

```
Bundles  →  Profiles  →  Hosts
   ↑     ↗     ↑      ↗    ↑
Features    Hardware     Users
```

- **`modules/features/`** — Software and service configurations
- **`modules/bundles/`** — Reusable aggregates of related features
- **`modules/profiles/`** — High-level roles combining bundles and
  features
- **`modules/hosts/`** — Per-machine configurations
- **`modules/users/`** — User account definitions
- **`modules/hardware/`** — Device and hardware configurations
- **`modules/core/`** — Infrastructure glue

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

# Validate, format, and update
nix flake check
nix fmt
nix flake update
```
