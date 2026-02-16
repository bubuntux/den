# den

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

Configuration flows from small, focused features up to complete host
definitions:

```
Features  →  Bundles  →  Profiles  →  Hosts
                                    ↗
                              Users
```

- **`modules/features/`** — Individual software and service
  configurations (audio, bluetooth, sway, neovim, printing, etc.)
- **`modules/bundles/`** — Reusable aggregates of related features
  (`base`, `desktop`)
- **`modules/profiles/`** — High-level roles combining bundles and
  features (`laptop`, `developer`, `gaming`, `work`, `wife`)
- **`modules/hosts/`** — Per-machine configurations that select
  profiles and set hardware options
- **`modules/users/`** — User account definitions that bridge NixOS
  and Home Manager; imported by hosts or profiles
- **`modules/core/`** — Infrastructure glue (dendritic wiring, Home
  Manager integration, VM helper, dev shell, formatting)

Features, bundles, and profiles can define both `nixosModules` and
`homeModules` in the same file. User modules define both a
`nixosModule` (account, groups) and a `homeModule` (packages,
programs), wiring them together internally via
`home-manager.users.<name>`.

### Layer Import Guidelines

The recommended import direction for each layer. When a change doesn't
follow these guidelines, consider a refactor that does (e.g., creating
a profile to wrap features instead of importing them directly from a
host).

| Layer | Recommended Imports | Avoid Importing |
| --- | --- | --- |
| **Features** | Other features (sparingly) | Bundles, profiles, hosts, users |
| **Bundles** | Features only | Other bundles, profiles, hosts, users |
| **Profiles** | Bundles, features, and users | Other profiles, hosts |
| **Hosts** | Profiles and users (plus hardware modules) | Features, bundles directly |
| **Users** | Features and profiles (homeModules only) | Bundles, hosts |

## Flake Inputs

| Input | Source |
| --- | --- |
| nixpkgs | nixpkgs-unstable |
| home-manager | nix-community/home-manager |
| nixos-hardware | nixos/nixos-hardware |
| flake-parts | hercules-ci/flake-parts |
| flake-file | vic/flake-file |
| import-tree | vic/import-tree |
| treefmt-nix | numtide/treefmt-nix |

## Usage

```bash
# Apply configuration to the current machine
sudo nixos-rebuild switch --flake .

# Build a specific host without applying
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel

# Test a host in a QEMU VM
nix run .#<hostname>-vm

# Validate all modules and configurations
nix flake check

# Format code (nixfmt + mdformat)
nix fmt

# Update flake inputs
nix flake update
```

## Adding a New Module

- Create a `.nix` file under the appropriate `modules/` subdirectory.
- The file should be a function taking `{ self, inputs, ... }` and
  defining flake outputs (e.g., `flake.nixosModules.my-feature = { ... };`).
- Reference other modules via `self.nixosModules`:
  ```nix
  imports = with self.nixosModules; [ bundle-base my-other-feature ];
  ```
- Stage the file (`git add`), then run `nix fmt` and `nix flake check`.

## License

[MIT](LICENSE)
