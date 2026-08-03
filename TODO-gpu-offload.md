# TODO: verify `gpu-offload` on zuko

zuko is the only hybrid host (Intel iGPU + NVIDIA dGPU on PRIME offload) and the
only machine that installs a render-offload command. None of this has run on
real hardware — it was worked out from source and evaluated configs. Delete this
file once checked.

Background, including why switcheroo-control was tried and dropped: CLAUDE.md,
**GPU render offload**.

## 1. The command exists under its new name

`hosts/zuko/default.nix` renames the script nixpkgs generates from
`hardware.nvidia.prime.offload.enableOffloadCmd`:

```bash
command -v gpu-offload      # expect /run/current-system/sw/bin/gpu-offload
command -v nvidia-offload   # expect nothing -- it was renamed, not added to
```

The second line matters: anything of yours still referring to `nvidia-offload`
(a shell alias, an existing Steam launch option) breaks at the rename.

## 2. It actually reaches the discrete GPU

```bash
glxinfo | grep "OpenGL renderer"              # baseline: Intel
gpu-offload glxinfo | grep "OpenGL renderer"  # expect NVIDIA
```

`glxinfo` is in `mesa-demos` — `nix shell nixpkgs#mesa-demos` if needed. For
Vulkan, `vulkaninfo --summary` under each.

## 3. Steam's FHS can see it — already verified

`profile-gaming` adds nothing to `programs.steam.extraPackages`, because the
host command is reachable inside the sandbox. Checked by running a real Steam
FHS on katara:

```console
$ steam-run sh -c 'command -v nixos-version'
/run/current-system/sw/bin/nixos-version
```

`/run` is bind-mounted in and the host `$PATH` is appended after `/usr/bin`, so
`gpu-offload` will resolve the same way. Nothing to do here unless step 4 comes
up empty, in which case re-run the line above on zuko.

## 4. End to end

Set a game's launch options to `gpu-offload %command%`, then confirm the dGPU is
really in use: `nvidia-smi` should list the game process, and with
`hardware.nvidia.powerManagement.finegrained` the card should drop back to
`D3cold` after quitting.

## Also unverified on zuko (unrelated to offload)

The Waybar GPU widget assumes nvtop's Intel backend reads DRM fdinfo and needs
no `CAP_PERFMON`. If the blue Intel reading never appears next to the green
NVIDIA one, that assumption is wrong.
