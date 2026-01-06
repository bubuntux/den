<!--
SYNC IMPACT REPORT
Version Change: 1.2.0 -> 1.3.0 (Added Reuse & Promotion Principle)
Modified Principles: None
Added Sections: Principle VIII. Reuse & Promotion
Removed Sections: None
Templates Requiring Updates: plan-template.md (Constitution Check), tasks-template.md (Reuse/Refactor Tasks) - ✅ Updated
Follow-up TODOs: None
-->

# NixOS Den Constitution

## Architectural Concepts

### Dendritic Pattern

The **Dendritic Pattern** is a configuration philosophy for Nix that relies on **Aspect-Oriented Design**. Instead of organizing code by "Host" (e.g., `hosts/laptop/configuration.nix`), code is organized by **Feature** (e.g., `modules/community/gaming.nix`).

- **Inversion of Control**: The module defines *where* it applies (NixOS, Home Manager, Darwin) rather than the host importing the module.
- **Reference**: [Dendritic Design Pattern](https://dendrix.oeiuwq.com/Dendritic.html)

### Den Library

**Den** is the specific implementation of the Dendritic pattern used in this repository. It provides the tooling for:

- **Recursive Loading**: Automatically finding and importing all `.nix` files in the module tree.
- **Unified Arguments**: Passing consistent arguments to all modules.
- **Reference**: [vic/den Repository](https://github.com/vic/den)

## Core Principles

### I. Dendritic & Aspect-Oriented Design

Configurations MUST be organized by feature or "aspect" rather than by host or operating system. A single module file should contain the configuration for that feature across all applicable environments (NixOS, Home Manager, Darwin). This inversion of control enhances flexibility and reduces duplication.

### II. Automated Discovery & Loading

Modules MUST be automatically discovered and loaded recursively. Manual `import` statements for feature modules are prohibited. The project utilizes tools (like `import-tree` or `haumea`) to ensure that adding a file to the directory structure automatically makes its configuration available.

### III. Tiered Module Structure

Modules MUST be categorized into three distinct tiers:

1. `auto`: Core, system-wide modules that are automatically loaded.
1. `community`: Generic, reusable modules shared across the community.
1. `personal`: Highly specific, user-tailored configurations.
   This structure ensures clear separation of concerns and promotes reusability.

### IV. Universal Compatibility

Modules MUST be designed to be as universal as possible. Where applicable, a module should provide configuration for both NixOS and Home Manager. Code should be written to be agnostic of the specific instantiation method, enabling reuse across different system types.

### V. Validated Configuration

Changes to configuration options and packages MUST be validated using the NixOS Model Context Protocol (MCP) tools (`nixos_info`, `home_manager_info`). This ensures that options exist, types are correct, and packages are available before code is committed.

### VI. Explicit External Dependencies

Modules relying on external flakes (e.g., `nixos-hardware`, `home-manager`) MUST declare them internally using `flake-file.inputs`. This ensures modules are self-contained and reproducible without implicit reliance on the root `flake.nix` or global arguments.

### VII. Flake Integrity & Workflow

The repository's flake state MUST remain valid throughout development.

- **Validation**: `nix flake check` MUST be executed before implementation (to establish a baseline) and after implementation (to ensure no regressions).
- **Input Registration**: When adding new dependencies/inputs, developers MUST run `nix run .#write-flake` to automatically register them in the root `flake.nix` before committing. Manual edits to `flake.nix` for inputs are discouraged.

### VIII. Reuse & Promotion

Existing modules MUST be prioritized. Before creating new configurations, developers MUST search for existing implementations in `community` or `auto`. When similar patterns or configurations emerge across multiple personal or specific scopes, they MUST be refactored into a generalized `community` module to facilitate reuse and reduce duplication.

## Governance

### Amendment Process

Amendments to this constitution require a Pull Request with a "Sync Impact Report" detailing the changes and their propagation to dependent templates. Changes must be ratified by the repository owner.

### Versioning

This constitution follows Semantic Versioning:

- **MAJOR**: Backward incompatible governance or principle removals/redefinitions.
- **MINOR**: New principle/section added or materially expanded guidance.
- **PATCH**: Clarifications, wording, typo fixes.

### Compliance

All feature specifications and implementation plans must explicitly state their adherence to these principles. Non-compliant code will be rejected during review.

**Version**: 1.3.0 | **Ratified**: 2025-12-31 | **Last Amended**: 2025-12-31
