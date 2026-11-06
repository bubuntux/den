# katara

The family/workstation AMD laptop, on a Dell WD19TB dock.

## The dock on katara

katara sits on a Dell WD19TB, and roughly half the time it is docked the
externals come up dark and the machine is unresponsive for ten to twenty
seconds. The fix is a **habit, not config**:

> Power the right panel **off**, connect the dock, then power it back on.

Everything below is why that works, and which explanations were measured and
eliminated — none of it is re-derivable from the code, and three of the dead
ends look convincing enough to cost an afternoon each.

**The constraint is two DP lanes.** There is no Thunderbolt or USB4 host —
`lspci` shows four plain AMD xHCI controllers and `/sys/bus/thunderbolt/devices/`
is empty — so this Thunderbolt dock runs as an ordinary USB-C one in DP alt mode
(`/sys/class/typec/port0/port0.0/svid` reads `ff01`). Carrying USB 3.x on the
same connector leaves two DP lanes, and they train at HBR3:

```
$ cat /sys/kernel/debug/dri/1/DP-6/link_settings
Current:  2  0x1e  16          # 2 lanes, 0x1e = HBR3 = 8.1 Gbps/lane
```

2 × 8.1 × 8/10 = **12.96 Gbps**. Two 2560×1440@60 need 2 × 7.25 = **14.5 Gbps**
uncompressed. They do not fit. The desk only works because DSC compresses them —
so DSC is not an optimisation here, it is load-bearing, and it is the fragile
part.

**The failure is at bring-up, not in the steady state.** With both sinks already
present when the cable goes in, the driver has to get DSC right across two
streams in one shot, and often does not. Bring one panel up first and the second
joins as an incremental payload add, which takes a path that works — hence the
habit. Dell describes the same DSC fragility on this dock family in KB 000214256,
where their Windows fix is to disable DSC outright and accept less resolution.

Reading the journal for a bad episode, in the order the lines matter:

| line | what it is |
|---|---|
| `enabling link 2 failed: 15` | the event itself |
| `EDID block 0 is all zeroes` / `Bad EDID, status3!` | MST sideband read failing after it |
| `scheduled expiry is in the past (-17140ms)` | sway measuring its own stall in `drm_mode_atomic_ioctl` — the only line that quantifies the hang |
| `ASSERT(i != copy_of_link_table.stream_count)` at `amdgpu_dm_helpers.c:207`, `Comm: sway` | teardown noise, removing a payload whose VCPI is already gone |

A run where `kanshi` never reaches `docked` and only one DP connector ever
appears is this same failure, caught earlier.

**Four dead ends, each measured rather than reasoned about:**

- **The kernel.** There *was* a real MST regression in this era —
  `1788ef30725d` "drm/amd/display: Fix pbn to kbps Conversion", which broke
  daisy-chained DP on 6.17.10 and 6.18.0 — but it was reverted upstream on
  2025-12-09 (`9837f8d57a54` in `linux-6.18.y`) and every 6.18.4x carries the
  revert. And `fill_dc_mst_payload_table_from_drm` is byte-identical between
  `linux-6.18.y` and mainline master, so no newer kernel changes the ASSERT
  either. There is nothing to upgrade to; verify a claimed fix actually touches
  this code before acting on it.
- **USB autosuspend.** The dock's four Realtek hubs were pinned to
  `power/control=on` via `services.udev.extraRules`. It was tried against this
  and did not help, so it was reverted rather than left in as a lucky charm.
- **The cable and the connector.** The USB tree dropping is *downstream* of the
  DP failure, not its cause: one capture has the DP link dying 37 s before USB
  followed, and another has no spontaneous USB drop at all. Reseating or
  replacing the cable fixes nothing.
- **Firmware.** Dock and BIOS are both current per LVFS.

Two ways out, if the habit ever stops being acceptable. Moving one panel to
katara's own `HDMI-A-1` leaves the dock a single 1440p60 at 56% of link capacity,
so DSC never engages — the robust option, at the cost of a second cable. Pinning
both panels to 50 Hz in `monitors.nix` also fits uncompressed (2 × 6.04 =
12.08 Gbps), one cable, worse refresh. Neither is worth doing pre-emptively.
