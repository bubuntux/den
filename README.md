# den

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue?logo=nixos)](https://nixos.org)
[![Flake](https://img.shields.io/badge/Nix-Flake-informational?logo=nixos)](https://nixos.wiki/wiki/Flakes)
[![Home Manager](https://img.shields.io/badge/Home%20Manager-enabled-blue?logo=nixos)](https://github.com/nix-community/home-manager)
[![Check](https://img.shields.io/github/actions/workflow/status/bubuntux/den/check.yml?label=Check&logo=github)](https://github.com/bubuntux/den/actions/workflows/check.yml)

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

```bash
# Apply configuration to the current machine
sudo nixos-rebuild switch --flake .

# Test a host in a QEMU VM
nix run .#<hostname>-vm

# Validate, format, and update
nix flake check
nix fmt
nix flake update
```
