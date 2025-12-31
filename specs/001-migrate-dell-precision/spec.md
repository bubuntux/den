# Feature Specification: Migrate Dell Precision 5680 Module

**Feature Branch**: `001-migrate-dell-precision`
**Created**: 2025-12-31
**Status**: Draft
**Input**: User description: "i want to migrate the dell-precision module into the new denditric pattern, the file has been created i want to make sure is equivalent, review what is missing once fully migrated remove the old version"

## Clarifications

### Session 2025-12-31

- Q: How should external dependencies like `nixos-hardware` be integrated into the new dendritic module? → A: Declare `flake-file.inputs.nixos-hardware.url = "github:nixos/nixos-hardware"` inside the module itself.

## User Scenarios & Testing

### User Story 1 - Maintain Hardware Support (Priority: P1)

As a system administrator, I want the new Dell Precision module to provide the exact same hardware support as the legacy configuration, so that my device continues to function correctly without regression.

**Why this priority**: The device must remain usable during and after the migration.

**Independent Test**: Verify that the generated NixOS configuration contains all the settings from the legacy file (Nvidia, Bluetooth, Audio, etc.).

**Acceptance Scenarios**:

1. **Given** the new module is enabled, **When** I build the system, **Then** the configuration should include `hardware.nvidia`, `hardware.bluetooth`, `services.fwupd`, and all other settings from the legacy file.
1. **Given** the migration is complete, **When** I check the filesystem, **Then** the legacy file `old/systems/x86_64-linux/inixell/dell-precision-5680.nix` should not exist.

### Edge Cases

- **Missing Inputs**: If the `inputs` argument (containing `nixos-hardware`) is not available to the module, the evaluation should fail with a clear error message rather than silently omitting hardware support.
- **Build Failure**: If the migrated configuration contains syntax errors or invalid options, the system rebuild must fail, preventing the user from switching to a broken configuration.
- **Partial Migration**: If the legacy file is not removed but the new module is enabled, a conflict might occur (though less likely with namespacing). The process must ensure the legacy file is removed.

---

## Requirements

### Functional Requirements

- **FR-001**: The module MUST declare `flake-file.inputs.nixos-hardware.url = "github:nixos/nixos-hardware"` and include the hardware imports (common-hidpi, pc-ssd, pc-laptop, cpu-intel, gpu-nvidia) from `inputs.nixos-hardware.nixosModules`.
- **FR-002**: The module `modules/community/dell-precision-5680.nix` MUST configure `hardware.enableRedistributableFirmware` and `hardware.enableAllFirmware`.
- **FR-003**: The module MUST configure `hardware.bluetooth` (enable and powerOnBoot).
- **FR-004**: The module MUST configure `hardware.graphics.enable`.
- **FR-005**: The module MUST configure the full `hardware.nvidia` suite (open, modesetting, nvidiaSettings, powerManagement).
- **FR-006**: The module MUST configure `boot.initrd.kernelModules` to include `snd-sof-pci`.
- **FR-007**: The module MUST retain the existing `ipu6` and `services` configurations (fwupd, bolt, pcscd, thermald).
- **FR-008**: The legacy file `old/systems/x86_64-linux/inixell/dell-precision-5680.nix` MUST be deleted.

### Module Requirements (NixOS Den)

- **MR-001**: Module Category: Community
- **MR-002**: Compatibility: NixOS
- **MR-003**: The module MUST follow the "dendritic" pattern (namespaced under `com.dell-precision-5680`).

## Success Criteria

### Measurable Outcomes

- **SC-001**: The new module configuration contains 100% of the settings defined in the legacy file.
- **SC-002**: The system evaluates successfully with the new module.
- **SC-003**: The legacy file is removed from the repository.

## Assumptions

- The `dendritic` pattern supports `imports` or an equivalent mechanism to include external hardware modules.
- `inputs` (for `nixos-hardware`) is available or can be made available to the module context.