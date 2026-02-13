# Project Overview

This is a **NixOS Configuration** repository managed as a **Nix Flake**. It uses a modular structure powered by [flake-parts](https://github.com/hercules-ci/flake-parts) and [flake-file](https://github.com/vic/flake-file) (with `import-tree`), allowing for a highly distributed and organized configuration.

The project structure is "dendritic," meaning the file organization within the `modules/` directory directly maps to the structure of the Nix flake outputs (e.g., `nixosModules`, `nixosConfigurations`).

## Directory Structure

- `flake.nix`: The entry point. Minimal logic; delegates to `modules/`.
- `modules/`: Contains all logic, configurations, and definitions.
  - `bundles/`: Aggregates multiple modules into reusable sets (e.g., `base.nix`, `desktop-base.nix`).
  - `core/`: Core infrastructure settings (e.g., `dendritic.nix`, `home-manager.nix`, `host-vm.nix`).
  - `features/`: Individual software or service configurations (e.g., `gnome`, `neovim`, `bluetooth`).
  - `hosts/`: Definitions for specific machines (NixOS configurations).
  - `profiles/`: High-level roles combining multiple features (e.g., `developer`, `laptop`, `server`).
  - `users/`: User-specific configurations (often integrating Home Manager).

# Building and Running

Since this is a standard Nix flake with some convenience wrappers, you can use standard Nix commands.

## System Reconstruction

To apply the configuration to the current machine (assuming the hostname matches a defined host):

```bash
sudo nixos-rebuild switch --flake .
```

To build a specific host:

```bash
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

## Virtual Machines

The project includes automation (in `modules/core/host-vm.nix`) to run any defined host as a QEMU virtual machine. This is excellent for testing changes without applying them to hardware.

```bash
# Run the 'katara' host in a VM
nix run .#katara-vm
```

## Updating Dependencies

To update the flake inputs (lockfile):

```bash
nix flake update
```

# Development Conventions

- **Flake-Parts & Dendritic**:
  - Modules are typically defined as function taking `{ self, inputs, ... }`.
  - They define flake outputs directly, e.g., `flake.nixosModules.my-feature = { ... };`.
  - Do not edit `flake.nix` manually unless adding new top-level inputs.
- **Imports**:
  - Use `self.nixosModules` to reference other modules within the flake.
  - Example: `imports = with self.nixosModules; [ bundle-base gnome ];`
- **Home Manager**:
  - Integrated via `modules/core/home-manager.nix`.
  - User configurations in `modules/users/` likely define Home Manager modules.
- **Naming**:
  - Hosts are named after Avatar: The Last Airbender characters (e.g., `zuko`, `katara`, `appa`).
  - Users are named after Teenage Mutant Ninja Turtles (e.g., `leo`, `mike`, `rafa`).
  - Profiles describe the device role or user role (e.g., `laptop`, `developer`).
- **Verification**:
  - **Verify Validity**: Use the configured MCP (or available search tools) to verify that packages and options exist before adding them.
  - **Flake Check**: Always run `nix flake check` after making changes to validate the configuration.
