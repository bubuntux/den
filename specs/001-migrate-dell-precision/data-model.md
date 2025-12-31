# Data Model: Dell Precision 5680 Module

**Branch**: `001-migrate-dell-precision`

## Module Options

The module will expose the following configuration structure under the `com.dell-precision-5680` namespace:

### `com.dell-precision-5680` (Namespace)

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `nixos.hardware.ipu6.enable` | `bool` | `true` | Enable IPU6 webcam support |
| `nixos.hardware.ipu6.platform` | `string` | `"ipu6ep"` | IPU6 platform identifier |
| `nixos.hardware.nvidia.prime.intelBusId` | `string` | `"PCI:00:02:0"` | Intel GPU Bus ID |
| `nixos.hardware.nvidia.prime.nvidiaBusId` | `string` | `"PCI:01:00:0"` | Nvidia GPU Bus ID |
| `nixos.services.hardware.bolt.enable` | `bool` | `true` | Enable Thunderbolt support |
| `nixos.services.fwupd.enable` | `bool` | `true` | Enable firmware updates |
| `nixos.services.pcscd.enable` | `bool` | `true` | Enable smart card reader |
| `nixos.services.thermald.enable` | `bool` | `true` | Enable thermal management |

## External Inputs

The module will declare the following inputs via `flake-file`:

- `nixos-hardware`: `github:nixos/nixos-hardware`

## Hardware Configuration (Internal)

The module will internally configure the following NixOS options when enabled:

- `hardware.enableRedistributableFirmware`: `true`
- `hardware.enableAllFirmware`: `true`
- `hardware.bluetooth.enable`: `true`
- `hardware.graphics.enable`: `true`
- `hardware.nvidia`: Full suite (open, modesetting, etc.)
- `boot.initrd.kernelModules`: `["snd-sof-pci"]`
