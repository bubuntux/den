---
description: "Task list template for feature implementation"
---

# Tasks: Migrate Dell Precision 5680 Module

**Input**: Design documents from `/specs/001-migrate-dell-precision/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), data-model.md

**Tests**: Tests are primarily validation of the generated configuration via `nixos-rebuild` or introspection.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1)
- Include exact file paths in descriptions

## Path Conventions

- **Module**: `modules/community/dell-precision-5680.nix`
- **Legacy**: `old/systems/x86_64-linux/inixell/dell-precision-5680.nix`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Verify legacy file content and backup `old/systems/x86_64-linux/inixell/dell-precision-5680.nix`
- [x] T002 Create empty module file at `modules/community/dell-precision-5680.nix`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Define dendritic namespace `com.dell-precision-5680` structure in `modules/community/dell-precision-5680.nix`
- [x] T004 Declare `flake-file.inputs.nixos-hardware` dependency in `modules/community/dell-precision-5680.nix`

**Checkpoint**: Module structure exists and dependency is declared.

---

## Phase 3: User Story 1 - Maintain Hardware Support (Priority: P1) 🎯 MVP

**Goal**: The new Dell Precision module provides the exact same hardware support as the legacy configuration.

**Independent Test**: The module can be enabled, and the generated configuration matches the legacy settings.

### Implementation for User Story 1

- [x] T005 [US1] Import `nixos-hardware` modules (common-hidpi, pc-ssd, pc-laptop, cpu-intel, gpu-nvidia) in `modules/community/dell-precision-5680.nix`
- [x] T006 [US1] Configure Audio (firmware, initrd kernel modules) in `modules/community/dell-precision-5680.nix`
- [x] T007 [US1] Configure Bluetooth (enable, powerOnBoot) in `modules/community/dell-precision-5680.nix`
- [x] T008 [US1] Configure Graphics and Nvidia (prime, modesetting, power management) in `modules/community/dell-precision-5680.nix`
- [x] T009 [US1] Configure Services (fwupd, bolt, pcscd, thermald) and Webcam (ipu6) in `modules/community/dell-precision-5680.nix`
- [x] T010 [US1] Validate configuration equivalence (manual review or dry-run build if possible)
- [x] T011 [US1] Remove legacy file `old/systems/x86_64-linux/inixell/dell-precision-5680.nix`

**Checkpoint**: User Story 1 functional, legacy file removed.

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T012 Verify external dependencies are declared via `flake-file.inputs` in `modules/community/dell-precision-5680.nix`
- [x] T013 Validate configuration options using NixOS MCP (`nixos_info`, `home_manager_info`) if applicable

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup. Blocks User Story 1.
- **User Story 1 (Phase 3)**: Depends on Foundational.
- **Polish (Final Phase)**: Depends on User Story 1.

### User Story Dependencies

- **User Story 1 (P1)**: Independent.

### Within User Story 1

- `flake-file.inputs` (T004) must be defined before imports (T005) can reference it.
- Validation (T010) should happen before Legacy Removal (T011).

### Parallel Opportunities

- T006, T007, T008, T009 (Configuration blocks) can be implemented in any order or in parallel once the structure (T003) and inputs (T004) are set.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Setup & Foundational: Create module and declare inputs.
2. User Story 1: Port all hardware settings.
3. Validate: Ensure configuration is correct.
4. Clean up: Remove legacy file.
