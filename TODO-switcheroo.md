# TODO: verify switcheroo offload on zuko

Open question from the `refactor(gaming): vendor-neutral GPU offload via switcherooctl` change. It has never run on real hardware — everything so far was
read out of source and evaluated configs. Run this on **zuko** (the only hybrid
host: Intel iGPU + NVIDIA dGPU on PRIME offload). Delete this file once settled.

## Why it might not be right

`switcherooctl launch` and `nvidia-offload` are both prefix commands, so Proton
/ pressure-vessel propagation affects them equally. Their dependencies do not:

| | `nvidia-offload` | `switcherooctl launch` |
|---|---|---|
| needs | `/nix` (bash shebang) | `/nix`, Python + PyGObject, **and the D-Bus system socket** |
| picks the GPU by | nothing, hardcoded | udev tag `switcheroo-discrete-gpu`, read over D-Bus |
| dependency missing | can't happen | **silently execs with no environment set** |

That last row is the whole risk. `switcherooctl` wraps `Gio.bus_get_sync` in a
bare `except` and falls through to a plain `os.execvp`, so a missing daemon or
an unreachable system bus means the game runs on the iGPU with no error at all —
it shows up as bad framerates, not as a failure.

## The checks

### 1. The daemon sees both GPUs

```bash
switcherooctl list
```

Expect two devices, the NVIDIA one with `Discrete: yes` and an `Environment`
carrying `__GLX_VENDOR_LIBRARY_NAME`, `__NV_PRIME_RENDER_OFFLOAD` and
`__VK_LAYER_NV_optimus`. No output at all means the daemon is not reachable —
that is the silent-failure case, not an empty machine.

### 2. Offload actually happens, and matches the vendor command

```bash
glxinfo | grep "OpenGL renderer"                      # baseline: Intel
switcherooctl launch glxinfo | grep "OpenGL renderer" # expect NVIDIA
nvidia-offload      glxinfo | grep "OpenGL renderer"  # should agree
```

`glxinfo` is in `mesa-demos`; `nix shell nixpkgs#mesa-demos` if it is not
installed. For the Vulkan side, `vulkaninfo --summary` under each.

### 3. The decisive one — does it work inside Steam's FHS?

This is what the Steam launch option actually runs in.

```bash
steam-run switcherooctl list
```

If this prints nothing while a plain `switcherooctl list` works, the D-Bus
system socket is not reaching inside the FHS, and switcheroo is the wrong tool
for the Steam path specifically. Everything else can still stand.

### 4. End to end

Set a game's launch options to `switcherooctl launch %command%` and confirm the
dGPU is actually in use — `nvidia-smi` should list the game process, and with
`hardware.nvidia.powerManagement.finegrained` the card should return to `D3cold`
after quitting.

## If it fails

The fallback is to keep the vendor-neutral *interface* without the daemon: give
the NVIDIA command a stable, vendor-free name in the hardware module, where the
vendor is a known fact anyway.

```nix
# modules/hardware/dell-precision-5680.nix
hardware.nvidia.prime.offload.offloadCmdMainProgram = "gpu-offload";
```

A future AMD hybrid host writes its own three-line `gpu-offload` exporting
`DRI_PRIME`; `profile-gaming` keeps shipping nothing vendor-specific, and the
Steam launch option is `gpu-offload %command%` everywhere. Deterministic, no
daemon, no Python — at the cost of failing loudly on a single-GPU host rather
than no-opping.

Note these are not exclusive. `services.switcherooControl` is worth keeping
regardless for the GNOME/KDE "Launch using Discrete Graphics Card" menu; only
the Steam launch option would change.

## Background

CLAUDE.md, **GPU render offload**.
