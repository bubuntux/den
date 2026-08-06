# zuko

The Precision 5690 workstation. The board, its GPUs and its fingerprint reader
are in `modules/hardware/CLAUDE.md`.

## The two LUKS containers on zuko

The reinstall left **two**, and both have to be named: `nvme0n1p2` holds the root
filesystem, `nvme0n1p3` (68.5 GiB) holds swap. Miss the second and the failure is
silent in the way that matters — `swapDevices` names the UUID *inside* the
container, so with nothing opening it the `dev-disk-by\x2duuid-….swap` unit sits
`inactive dead` behind a device job that times out. Nothing appears in
`systemctl --failed` and `free` simply reports zero swap, which is how the
machine ran swapless for a while. Check `swapon --show`, not the unit list.

**Two containers is still one passphrase.** systemd-cryptsetup caches what you
type and tries it on the others, so both units start together and both report
`Set cipher` at the same instant once the password is in — no keyfile needed
while the two share a passphrase. Note the mapper numbering is *not* stable
across boots: whichever unlocks first becomes `dm-0`, so check
`/dev/mapper/luks-<uuid>` rather than a `dmN` you saw last boot.

68.5 GiB against 62 GiB of RAM is the installer sizing that partition for
hibernation, but nothing here configures it: `boot.resumeDevice` is unset. Set it
to the opened mapper device if hibernate is ever wanted.

**Both containers carry `tpm2-device=auto`, and the second one is the subtle
half.** The reason to enrol at all is that the Moonlander cannot reach the
passphrase prompt — it hangs off the WD19TB, so it is behind a Thunderbolt PCIe
tunnel that only exists once `boltd` authorises the dock, and `boltd` is
userspace. In initrd the dock's USB controller has not been tunnelled yet, so no
HID driver can help; only the internal i8042 keyboard works. Once root unlocks
from the TPM there is no typed password left for systemd-cryptsetup to cache, so
a swap container without its own enrolment would start prompting again — the
opposite of the point. `crypttabExtraOpts` is systemd-stage-1 only, which is
what this host uses.

**What that binding is actually worth here: very little.** `bootctl` reports
Secure Boot disabled and no measured UKI, so PCR 7 is the same whatever is
booted — someone holding the laptop boots their own kernel and the TPM releases
the key. It defends a *bare disk* (RMA, resale, disposal) and not much else. The
PCRs that would defend the machine (4, 9) are remeasured on every rebuild and
would break unlock at each switch, so they are not usable without signed policy.
Making this meaningful means Secure Boot via lanzaboote, at which point PCR 7
starts to mean something. Treat the current setup as convenience with a
passphrase fallback, not as protection against laptop theft.

**`allowDiscards` is what makes `common-pc-ssd` mean anything.** That module is
one line — `services.fstrim.enable` — and LUKS refuses discards by default, so
the timer ran weekly against a mapper device advertising `discard_max_bytes = 0`
and trimmed only `/boot`, which is vfat on the bare ESP. `lsblk -D` is the quick
check: `DISC-GRAN`/`DISC-MAX` read `0B` on the mapper row while the NVMe row
reads `512B`/`2T`. It is on for root and deliberately **off for swap**: the flag
leaks which blocks are in use to anyone holding the powered-off disk, and a
linearly-written swap area gains least from TRIM, so it is the one container
where the trade is not worth taking.
