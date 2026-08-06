# Hardware

zuko is the only machine with a module here, and the only hybrid-GPU host.
Repo-wide rules are in the root `CLAUDE.md`; the disks live in
`modules/hosts/zuko/CLAUDE.md`.

## Meteor Lake, not Raptor Lake

zuko is a **Precision 5690** — Core Ultra 9 185H, Arc iGPU `8086:7d55`, RTX 2000
Ada Laptop `10de:28b8`, Wi-Fi 7 BE201. It was configured as a **5680** for a
while, which is a Raptor Lake machine: a whole generation off, so the module was
renamed rather than edited in place. Read `hardware/dell-precision-5690.nix`
against this list before assuming anything in it is still true of the board.

**There is no `dell-precision-5690` in nixos-hardware.** The closest is
`dell-precision-5490`, same generation and same iGPU PCI id, and it independently
states the two bus IDs this machine reports (`PCI:0:2:0` / `PCI:1:0:0` — check
against `lspci` before trusting either). Its `i915.force_probe=7d55` is gated on
kernels older than 6.7 and so is dead for us.

**Look past `nixosModules` for the per-generation pieces.** Two of the three
things this module wants from nixos-hardware are not exported by its `flake.nix`
and have to be imported by path:

| path | what it is |
|---|---|
| `common/cpu/intel/meteor-lake` | `cpu-only.nix` plus `gpu/intel/meteor-lake`, whose whole body is `vaapiDriver = "intel-media-driver"` |
| `common/gpu/nvidia/ada-lovelace` | the base nvidia module plus `hardware.nvidia.open = lib.mkOverride 990 (…)` |

Both replace a line this module used to hand-write, and both are easy to miss:
`nixosModules` exports `common-cpu-intel` and only three of the twenty
`common-gpu-intel-*` generations (comet-lake, kaby-lake, sandy-bridge), so the
attribute list makes it look as though Meteor Lake is unsupported when the
directory is right there. `ls` the input rather than trusting the attribute set.

**`common-gpu-nvidia` is `prime.nix`, and the plain one is
`common-gpu-nvidia-nonprime`.** The names are inverted from what they suggest,
and getting it wrong fails at *build* rather than at runtime: nixpkgs'
`nvidia.nix` sets `prime.offload.enable = lib.mkDefault reverseSyncCfg.enable`,
so a `mkDefault true` beside it is a conflict, not an override. prime.nix's
`mkOverride 990 true` is what settles it — which means the `offload.enable` and
`enableOffloadCmd` lines that sat in this module for ages were never
load-bearing, and only the bus IDs are genuinely ours to state. Dropping
`common-gpu-nvidia` for the directory is what surfaced all of that.

Three more things the generation change invalidated:

- **i965 is dead weight on Xe-LPG, and the generic import is what installs it.**
  `common-cpu-intel` pulls in `common-gpu-intel`, whose `vaapiDriver = null`
  default means "install both because we don't know" — so `intel-vaapi-driver`
  and `intel-ocl` landed on a machine where i965 tops out at Gen9. Naming the
  generation is what drops them, worth **223 MiB** off the system closure per
  `nix store diff-closures` (203.6 for intel-ocl, 16.0 for intel-vaapi-driver,
  3.6 for the `ncurses-abi5-compat` only intel-ocl wanted). Measure that way
  rather than with `du` on the store paths, which reports 204 and 8 and misses
  what leaves with them. OpenCL is unaffected: Gen12+ is served by
  `intel-compute-runtime`, which arrives on the media-driver side of that same
  conditional.

- **`common-hidpi` was a no-op** and is no longer imported: since kernel 6.8 the
  console font is set by the kernel, so the module's only two settings are behind
  a `versionOlder … "6.8"`. `console.font` evaluates to `null` with or without it.

- **The built-in camera works on this generation, and the blacklist is gone.**
  The 5680 blacklisted `intel_ipu6`, `intel_ipu6_isys`, `ipu_bridge` and
  `ov02c10` because the IPU6 gave raw Bayer nodes no browser could use and made
  Firefox's camera enumeration take ~50s. That entry had been naming the wrong
  sensor anyway — this board is `ov02e10` on a Meteor Lake IPU (`8086:7d19`) —
  so it was dropped and retested rather than corrected. Neither symptom
  reproduces: the kernel reports `Found supported sensor OVTI02E1:00` /
  `Connected 1 cameras`, and libcamera turns it into a **`Built-in Front Camera`** PipeWire source advertising real BGR modes up to 1366x768, which
  wireplumber makes the default video source.

  The 48 `Intel IPU6 ISYS Capture N` nodes are still there and are still junk,
  but they cost nothing measurable now: opening all 53 `/dev/video*` takes
  **0.2s**, and wireplumber creates *no* source for them, so anything reaching
  the camera through PipeWire or the portal sees exactly three — two BRIO and
  the built-in. Only a program enumerating `/dev/video*` itself sees the noise.
  Check `wpctl status` before believing a report that the camera is missing; the
  raw nodes appear under Devices and mean nothing.

## The fingerprint reader, and why only sudo gets it

Goodix `27c6:634c`, and it **works** — this section used to claim the opposite
("present and cannot be used", on the grounds that libfprint 1.94.10's
`goodixmoc` did not know the id). It does: `libfprint/drivers/goodixmoc/goodix.c`
carries `{ .vid = 0x27c6, .pid = 0x634C }` in its id table and again in the
`max_enroll_stage = 12` switch, on the stock `v1.94.10` tag, with nixpkgs
patching only realtek/elan/focal. Whatever that list of ids was read off, it was
not this driver. It is a press pad, not a swipe, so enrolling is 12 presses of
`fprintd-enroll`.

`services.fprintd.enable` is the whole daemon, but it is **not** the whole
change, because `security.pam.services.<name>.fprintAuth` defaults to that value
for *every* PAM service — thirty of them here. So the hardware module inverts
that default with a submodule fragment (`#fprint-opt-in`) and opts `sudo` and
`sudo-i` back in by name. A new PAM service therefore arrives without a
fingerprint, which is the direction to fail in.

Which surfaces were rejected, and why they are not worth retrying:

- **greetd / login.** `pam_fprintd` is `sufficient` and sits at order 11400,
  ahead of `pam_unix` at 11700 — and `pam_gnome_keyring` is further down the
  same *auth* stack. A `sufficient` success short-circuits the rest, so a
  fingerprint login means the keyring never sees a password, and the user
  service in `session/wayland.nix` has an unlocked daemon to adopt only because
  PAM unlocked one. Fingerprint at the greeter re-creates exactly the
  out-of-nowhere password prompt that section exists to prevent.
- **swaylock.** Two things in swaylock's own `pam.c`: the auth worker blocks on
  `read_comm_request()` and only calls `pam_authenticate` *after* a submit, so
  the sensor is dead until you press Enter; and `PAM_TEXT_INFO`/`PAM_ERROR_MSG`
  both hit a bare `break`, so the "Place your finger…" prompt is discarded and
  nothing on screen says it is waiting. Revisit only with a short `timeout=`.
- **polkit-1.** Untested — zuko's agent is `lxqt-policykit-agent`.
- **LUKS at boot.** Impossible: initrd, no fprintd, no D-Bus. The TPM enrolment
  covers that ground.

The stall to know about: with no finger presented, `pam_fprintd` waits
`timeout=30` and then returns `PAM_AUTHINFO_UNAVAIL` **once** — `if (data->timed_out)`
returns rather than looping, so it is 30s, not `max-tries` × 30s. `max-tries=3`
burns down only on a genuine no-match. Both are module arguments
(`security.pam.services.sudo.rules.auth.fprintd.args`) if 30s ever feels long.

sudo is the surface that suits it because **sudo-rs** prints the prompt and
keeps the escape hatch: `CLIConverser::handle_info` writes `[sudo] <msg>` to the
tty, and `SignalGuard::unblock_interrupts` leaves SIGINT live, so Ctrl+C drops
straight to the password. zuko runs sudo-rs, not sudo — but this needed no
thought either way, since `security.sudo` and `security.sudo-rs` declare the
same two PAM service names.

## GPU render offload

zuko is the only hybrid host — Intel iGPU plus an NVIDIA dGPU on PRIME offload,
all of it in `hardware/dell-precision-5690.nix`, where the vendor is a known
fact. katara is a single AMD APU. So "run this on the discrete card" has to be
real on one machine and simply absent on the other.

**The dispatch happens at eval time, not at runtime.** The host already knows
its own GPU topology, so nothing needs to discover it while a game launches.
Each host that can offload installs a command called **`gpu-offload`**, and a
Steam launch option reads `gpu-offload %command%` whatever the machine:

| host | what provides `gpu-offload` |
|---|---|
| zuko | `hardware.nvidia.prime.offload.enableOffloadCmd`, renamed via `offloadCmdMainProgram` |
| a future AMD-dGPU host | its own `writeShellScriptBin` exporting `DRI_PRIME` |
| katara, or anything single-GPU | nothing — there is no second card to reach |

zuko therefore costs **zero extra closure**: nixpkgs already generates that
script (`hardware/video/nvidia.nix`) and the Dell module already enables it.
The host only renames it:

```nix
hardware.nvidia.prime.offload.offloadCmdMainProgram = "gpu-offload";
```

`profile-gaming` contributes nothing to this. It is a *capability* and may not
know the GPU topology; Steam reaches the host command through `PATH` (see
below). A single-GPU host has no `gpu-offload` at all, so a launch option
copied there fails loudly rather than silently rendering on the wrong card.

The AMD side, when it is ever needed, is
[`DRI_PRIME=pci-0000_03_00_0`](https://docs.mesa3d.org/envvars.html#envvar-DRI_PRIME)
— the udev `ID_PATH_TAG`, **not** `1`. Do not reuse the NVIDIA script for it:
that one exports `__GLX_VENDOR_LIBRARY_NAME=nvidia` unconditionally, which on
an AMD host breaks every game launched through it, silently and only at
runtime.

**Steam needs no `extraPackages` entry for this**, which was checked by running
it rather than by reading the source:

```console
$ steam-run sh -c 'command -v nixos-version'
/run/current-system/sw/bin/nixos-version
```

The FHS rootfs carries no `/run` of its own, so bubblewrap auto-binds the host
one, and the FHS `/etc/profile` appends the host `$PATH` after `/usr/bin`.
Anything in `environment.systemPackages` is therefore reachable from a launch
option. `profile-gaming` used to hand-roll a `writeShellScriptBin "nvidia-offload"` into `extraPackages`, byte-identical to the one nixpkgs
already installs; it was never needed.

### Why not switcheroo-control

[`switcherooctl launch`](https://gitlab.freedesktop.org/hadess/switcheroo-control/-/blob/3.0/src/switcheroo-control.c#L282)
does the same job by asking a D-Bus daemon which card is discrete, then applying
`__GLX_VENDOR_LIBRARY_NAME`/`__NV_PRIME_RENDER_OFFLOAD`/`__VK_LAYER_NV_optimus`
for `nvidia`, or `DRI_PRIME=<ID_PATH_TAG>` for `amdgpu`/`radeon`/`i915`/`xe`,
plus `VK_LOADER_DRIVERS_SELECT` for either. It was used here briefly. Three
reasons it lost, worth knowing before anyone reaches for it again:

- **It duplicates something already present.** zuko gets the NVIDIA script free
  from `enableOffloadCmd`; switcheroo adds a **328 MiB** closure
  (`pygobject-*-dev` alone is 313 MiB) plus a daemon to do the same thing.
- **Its failure mode is silent.** `switcherooctl` wraps `Gio.bus_get_sync` in a
  bare `except` and falls through to a plain `os.execvp`, so an unreachable
  daemon means the game runs on the iGPU with no error — bad framerates, not a
  message. Eval-time dispatch cannot fail that way.
- **Runtime discovery buys nothing here.** Its vendor-neutrality only pays off
  when the machine is unknown at build time, which is never true of a NixOS
  host.

Its one remaining advantage is the GNOME/KDE "Launch using Discrete Graphics
Card" menu, which reads that D-Bus service. zuko runs Sway, so that is worth
nothing today. A future hybrid host running GNOME would be a real reason to
enable `services.switcherooControl` again — alongside `gpu-offload`, not
instead of it.

One NVIDIA detail either way: `__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0` is
only needed for multi-NVIDIA setups — upstream switcheroo omits it deliberately,
the nixpkgs script sets it. And none of this replaces `hardware.nvidia.prime`,
which is what makes offload possible at all.
