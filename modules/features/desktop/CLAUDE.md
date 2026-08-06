# Desktop features

The bar, the terminal and the widgets on them -- everything here is
DE-agnostic. The compositors are in `session/CLAUDE.md`; repo-wide rules and the
`den.desktop` option table are in the root `CLAUDE.md`.

## Choosing a bar

`den.desktop.bar` picks the renderer — `"waybar"` (default) or `"ironbar"` — and
the enum values are the Home Manager module names, so `nixos.session-wayland`
pushes the match at every user. It is host-level and single-valued for the same
reason `loginManager` is.

**Which bars exist and which one starts are separate questions.**
`den.desktop.barsInstalled` (default `[ bar ]`) is the set that gets units at
all; `bar` is the one an anchor *wants*. Everything else is installed and inert,
so comparing them inside a live session is two `systemctl --user` lines and no
rebuild:

```console
$ systemctl --user stop waybar-sway
$ systemctl --user start ironbar
```

One unit, because the two producers are `WantedBy=ironbar.service` rather than
the session target — Home Manager writes `<unit>.wants/` for a service just as
it does for a target — and `PartOf` it, so they stop with it too. There are two
of them rather than one because their cadences differ by 180×: a 10s curl
timeout in the 900s weather fetch must not stall the 5s GPU reading.

katara carries both for that reason. It is not the default because ironbar's
closure is **212 MiB on top of waybar's** (47 paths, 26 of them `-dev` outputs
worth 89 MiB — measured with `comm` over the two `nix path-info -r` listings),
and a host that has settled on one bar should not pay for the other. Each
renderer hangs the `Install.WantedBy` of *the unit the session starts* on
`den.session.activeBar` matching its own name — the user-scoped restatement of
`den.desktop.bar`, since Home Manager cannot read NixOS config — and
`session-anchors` asserts the whole topology: the bar names its target exactly,
its producers name the bar, and the losing renderer's units name nothing.

The two are not interchangeable implementations of one design; they disagree
about the thing this repo cares most about:

| | waybar | ironbar |
|---|---|---|
| bars per host | one **per session**, from `den.session.bar` | **one**, for all sessions |
| what starts it | that session's anchor | `den-session.target` |
| module state across monitors | one instance **per output** | also per output |
| the way out of that | scope modules per output, or cache | **ironvars** |
| toolkit | GTK3 | GTK4 |

**Measured, not assumed** — one script polled at 2s across two outputs for ~9s:
waybar ran it **10 times**, ironbar **10 times**, yambar/eww/quickshell 5, 5 and
4\. Ironbar does *not* fix per-monitor duplication by existing, and the note that
used to sit at the top of `waybar.nix` recommending it for that reason was
wrong.

What ironbar has instead is
[**ironvars**](https://github.com/JakeStanger/ironbar/wiki/ironvars): global
values in the daemon, set over IPC (`ironbar var set KEY VALUE`) and referenced
as `#name` anywhere a dynamic string is taken. One producer, every bar updates.
Verified the same way: one `ironbar var set` put the value on both monitors
while an embedded `{{2000:script}}` next to it ran 8 times in 4 ticks. So
`features/desktop/ironbar.nix` has **no polling module at all** — the GPU,
weather, failed-unit and power-profile readings come from the two producer
services above, and `set_var` swallows failure because a producer outlives any
one bar process and, `After=ironbar.service` notwithstanding, can still beat the
daemon to the socket at login.

Five more things that shaped the ironbar file:

- **One bar for every session works because ironbar detects its compositor at
  startup**, from `SWAYSOCK` / `HYPRLAND_INSTANCE_SIGNATURE` / `NIRI_SOCKET`, in
  that order (`src/clients/compositor/mod.rs`). So `workspaces` needs no
  per-session variant — which is the whole reason this renderer ignores
  `den.session.bar`. Two consequences: a new session must export its socket
  through `uwsm finalize` the way sway does with `SWAYSOCK`, and a compositor
  ironbar does not know (**mangowc**) makes `workspaces` fail — the module is
  dropped with `failed to create module` in the journal and a gap in the bar,
  exactly waybar's failure mode.
- **A module goes in only where every installed session can back it.** ironbar's
  matrix is per module — `workspaces` is sway/hyprland/niri, `bindmode` is
  sway/hyprland — so `supportedBy` in the file mirrors that and drops a module
  the moment a host installs a session that cannot serve it. This was written as a
  prediction and is now what happens: katara installs niri, so its ironbar has no
  mode indicator, and no file was edited to make that so.
- **Native modules replace three of waybar's four exec widgets**: `brightness`
  for `custom/backlight`, `inhibit` for `custom/idle-inhibitor`, and `sys_info`
  for cpu, memory *and* `custom/temp`. Note `{temp_c}` with no sensor reduces
  with `max`, so it is the hottest sensor on the board, not waybar's package
  reading — expect a couple of degrees' difference. Nothing replaces `privacy`,
  `gamemode` or `sway/scratchpad`.
- **The styling is ironbar's own `minimal` theme, on purpose.** This bar started
  out with a Catppuccin stylesheet mirroring waybar's, and it was dropped while
  the renderer is still being judged: a hand-written 130-line CSS is a lot of
  opinion to carry for a bar that may not stay, and comparing the two is only
  meaningful once one of them looks like itself. So the module writes no CSS at
  all and the unit names `-t minimal`. **That is not the same as omitting `-t`**,
  which is the trap: with no theme ironbar derives `style.css` from the config's
  *parent directory* — a store path, which has none — then logs `styles at '/nix/store/style.css' not found`, raises its error level, and falls back to
  the minimal theme anyway. So the look would be identical and
  `--validate-config` would exit 1, taking `ironbar-config` with it (measured
  both ways: `-t minimal` exits 0, no `-t` exits 1). Restyling means adding a
  `styleFile` back and pointing `-t` at it.
- **The clock module cannot show a second timezone**, which is worth knowing
  before anyone tries to add one. `ClockModule` (`src/modules/clock.rs`) is
  hardcoded to `chrono::Local` and offers only `format`, `format_popup`,
  `locale`, `show_week_numbers` and the layout keys — `chrono-tz` is not even a
  dependency, so a second `{ type = "clock"; }` prints local time twice. Setting
  `TZ` on the unit is no way out either: it is process-wide, so it would move
  *every* clock on the bar. The only route is a `label` per zone driven off the
  5s producer (`TZ=<zone> date`), which costs the calendar popup a real clock
  module gets and wants `%a` in its format, since the point of a remote clock is
  a zone whose *date* differs — local Mon 22:40 is already Tue in both UTC and
  Tokyo, so a bare `%H:%M` reads as an impossible time rather than tomorrow.
  UTC and Tokyo labels were built that way and then removed by preference; the
  bar carries the local clock alone.

Both renderers take their GPU and weather numbers from **`self.lib.barScripts`**
(`features/desktop/bar-scripts.nix`), a function of `pkgs` rather than a module,
so switching bars cannot change what the bar says. waybar consumes their JSON
directly; ironbar pipes `.text`/`.tooltip` into ironvars.

`ironbar --validate-config` rejects unknown fields and bad enum variants and
needs no display, so the generated config goes through it in the
`ironbar-config` check. Give it a `HOME`: without one it dies on its own log
directory before it reads the config, and reports that instead.

## Choosing a terminal

`den.desktop.terminal` picks the terminal — `"ghostty"` (default) or `"foot"` —
and like `den.desktop.bar` the enum values are the Home Manager module names, so
`nixos.session-wayland` pushes the match at every user and the other one is never
installed. Host-level and single-valued, for the same reason.

**It was not chosen for the GPU.** foot renders on the CPU into shm buffers and
sits at the top of published Wayland latency benchmarks; at 2×1440p60 there is no
throughput problem for a GPU to solve, and some GL terminals are *slower* to the
screen because they wait on a frame callback. What ghostty brings is defaults,
shell integration and the kitty graphics protocol. What it costs is a live
dependency on the GL stack, which foot does not have — so foot stays in the enum
as the fallback when a driver update goes wrong, not as a legacy entry.

The closure argument is the one that is easy to get backwards. Measured against
`cache.nixos.org`, ghostty's full closure is **1018 MiB** against foot's 95 —
but nearly all of it is libadwaita, GTK4, pipewire and gst-plugins-bad, which
katara already has from GNOME:

| | full closure | not already on katara |
|---|---|---|
| foot | 95 MiB | 0 |
| ghostty | 1018 MiB | **29 MiB** |
| kitty | 595 MiB | 66 MiB |
| alacritty | 235 MiB | 12 MiB |
| wezterm | 247 MiB | 165 MiB |

zuko is where that stops holding: sway with waybar brings no GTK4, so ghostty
pulls the toolkit for real there. Selecting `"ironbar"` on a host changes the
answer again, since that bar is GTK4 too.

Three things that shaped the two modules:

- **The command is not the module name.** foot is reached through
  **footclient**, because `programs.foot.server.enable` gives a `foot.service`
  the session starts and a client that attaches to it instead of paying process
  startup per window. So each module states its own command in
  **`den.session.terminal`**, and sway reads that rather than the host option —
  Home Manager cannot see NixOS config, the same wall that put `den.session.anchors`
  next to `den.desktop.sessionAnchors`. The option has **no default** on purpose:
  a terminal module that forgets to set it fails evaluation, rather than leaving
  `Mod+Return` bound to a binary nothing installed.

- **foot's server target needs no override.** `programs.foot.server.systemdTarget`
  defaults to `wayland.systemd.target`, which `session-wayland` already points at
  `den-session.target` — so it lands on the session anchor for free. Setting it
  to `graphical-session.target` would start a foot server under a GNOME login in
  the same home; `terminal-choice` asserts it does not.

- **`TERM` is left alone; the ssh features handle the remote instead.** ghostty
  announces `xterm-ghostty`, whose terminfo is on no remote host, and the
  obvious fix — `term = xterm-256color` — is the wrong one: it makes every
  *local* program treat ghostty as an xterm, losing undercurl and the rest of
  what the real entry describes, to solve a problem that only exists over ssh.
  `shell-integration-features` carries a targeted answer, off by default:
  `ssh-terminfo` installs ghostty's entry on the remote with `infocmp`/`tic` on
  first connection and caches that it did, and `ssh-env` forwards `COLORTERM`
  and friends — together they fall back to `xterm-256color` *only* when the
  install fails, which is exactly the old behaviour, only when needed. Setting
  the key replaces the whole default list, so `cursor,no-sudo,title,path` are
  repeated verbatim alongside the two being switched on.

  Its limit is worth knowing before trusting it: it is a **shell function
  wrapping `ssh`**, so it is not inherited by child processes. `ssh` from a
  script, `mosh`, or a tool that spawns its own (rsync, git, gcloud) gets
  `xterm-ghostty` on a host with no such terminfo. That only bites an
  interactive TUI, which is not usually how those are reached. `infocmp` and
  `tic` are needed locally and come from ncurses, already in every host's
  closure. foot, which has no equivalent, still pins `term = xterm-256color`.

  **Its second limit is `sudo` on the far side, and it is a different bug from
  the one above.** `tic -x -` writes into the *invoking user's* `~/.terminfo`,
  so on appa `infocmp xterm-ghostty` succeeded as bbtux and missed under `sudo`,
  whose `HOME` is `/root` — every ncurses program run privileged reported
  `terminal not found` while the same program unprivileged was fine. Two things
  that look like the fix and are not: `security.sudo.keepTerminfo` is already on
  by default and forwards `TERMINFO_DIRS`, which never names `~/.terminfo`; and
  ghostty's own `sudo` shell-integration feature is a *local* shell function
  wrapping the local `sudo`, so it is nowhere near the remote one — which is why
  `no-sudo` stays in the feature list rather than being flipped in response to
  this. The fix has to be on the machine being reached.

  That limit bites twice on zuko, and each half is answered where the shell
  actually is. **`work` is not ssh at all**: `machinectl shell` hands the host's
  `TERM` to the container, which had terminfo for neither terminal, so every
  login shell there greeted itself with `can't find terminal definition`.
  **`bundle-base` sets `environment.enableAllTerminfo`**, which answers that and
  the sudo gap at once: the entries land in the system path and therefore in
  `/etc/terminfo`, which ncurses searches for every user, root included. It is
  terminal-agnostic, so flipping `den.desktop.terminal` — or arriving from some
  other terminal over ssh — cannot break it again, and it costs 78 KiB across
  thirteen terminfo outputs (only tmux's references anything, and that is
  ncurses, which every NixOS system path carries anyway). It sits in the base
  bundle rather than on the servers because the machine that needs it is
  whichever one you ssh *into*, which is all of them.
  **`cvm` is `ssh` run from `sh -l -c` inside that container**, three processes
  below the zsh that holds the wrapper, so it goes through a container-side
  `ssh-cvm` that repeats what the ghostty feature does: push `infocmp -0 -x`
  through `tic -x -`, fall back to `xterm-256color` when that fails, and cache
  the success under `~/.cache/ssh-cvm/$TERM` — a path bind-mounted from the
  host, so it outlives the container. Two things that shaped those nine lines:
  the marker is keyed on `$TERM` rather than on the host, so a terminal switch
  re-runs the install rather than trusting a stale success; and the local
  `infocmp` is a step of its own rather than the head of the pipe, because
  **`tic -x -` exits 0 on empty input** — piping a failed lookup straight into
  ssh would report success and cache it.

- **A new window opens at `~`, and one key is what does it.**
  `window-inherit-working-directory = false` is the whole change: `Mod+Return`
  reaches the *running* ghostty (GTK single-instance), which would otherwise
  clone the focused window's shell cwd. What it falls through to is
  `working-directory`, whose default is `inherit` when launched from a shell and
  **`home` from anything else** — `probableCliEnvironment` in
  `config/Config.zig`, which is also what decides single-instance, so the
  process serving `Mod+Return` is by definition the non-shell case and the
  fall-through is already home. Setting `working-directory = "home"` alongside
  would look tidier and would cost the one behaviour worth keeping: `ghostty`
  typed in a project shell still opens there, because that launch is "probable
  CLI" and gets a process of its own. Tabs and splits are untouched —
  `tab-inherit-working-directory` and `split-inherit-working-directory` are keys
  of their own, both still true.

- **The theme is chosen against helix's, which is `onedark`** (`features/editor/helix.nix`).
  Scoring all 463 bundled ghostty themes against that palette by weighted RGB
  distance ranks **Atom One Dark** first by a factor of four — every accent
  byte-identical, foreground included. **One Dark Two** is what is actually set:
  the same family a few points lighter, with a notably brighter foreground
  (`#e6e6e6` against `#abb2bf`) and only green (`#98c379`) still exact. That is
  a deliberate preference for the brighter variant, not an oversight — do not
  "correct" it back to the closest match.

  The theme is taken whole, background included, and that is worth knowing
  before someone reports it as a bug: `onedark.toml` sets
  `"ui.background" = { bg = "black" }`, so helix paints `#282C34` across the
  grid while the theme's `#21252b` stays in ghostty's padding — a slightly
  darker ring around the editor. Setting `background = "#282c34"` next to the
  theme removes it, and works regardless of where the key lands, since an
  explicit colour beats `theme` whatever the order. Verified rather than
  assumed, because Home Manager sorts keys alphabetically and `background`
  therefore sits *above* `theme` in the generated file: with `theme` alone
  `+show-config` reports `background = #21252b`, and with the override it drops
  out of the report entirely — ghostty omits values equal to its default, and
  its default background is `#282c34` already.

  Note this makes the terminal One Dark while both bars are Catppuccin Mocha.
  That is deliberate: the editor fills the window and the bar is a strip, so the
  terminal matches what is inside it.

- **`window-decoration = server`, and `none` is the trap.** `~/.config/ghostty/config`
  is home-wide, so katara's GNOME user reads the same file — and `none` would
  leave her a window with no titlebar and no close button. `server` is the one
  value that is right in both: sway serves `org_kde_kwin_server_decoration` and
  then honours `titlebar = false`, while GNOME does not serve it and ghostty
  documents the fallback as client-side decorations, which is the headerbar she
  wants. This is the `xdg.userDirs.desktop` tie-break again — least wrong in the
  desktop that did not ask for it. Note the option is an enum
  (`auto`/`client`/`server`/`none`), not the boolean it once was, so `false` is
  rejected outright and `ghostty-config` is what says so.

`ghostty +validate-config` catches both of those last two classes and needs no
display, so the generated config goes through it in the `ghostty-config` check.
It wants a `HOME`, exactly like ironbar's validator.

Nothing installs a terminal system-wide any more: `programs.sway.extraPackages`
used to carry `foot`, which was both a second install path and the wrong terminal
the moment this option existed.

ghostty comes from **nixpkgs, not [its own flake](https://ghostty.org/docs/install/pre)**.
That page is the *prerelease* one: its flake tracks `tip`, and upstream publishes
no tagged release beyond it — `v1.3.1` is the newest tag and is exactly what
nixpkgs has, prebuilt at 16.6 MB. The flake would buy a source build of Zig and
a new input to track a nightly, for a version that is already current.

## One bar per session

That heading is waybar's half of the story; the shape below applies when
`den.desktop.bar = "waybar"`, and `den.session.bar` simply goes unread otherwise.

Waybar lives in `features/desktop/waybar.nix` and names no compositor. Of the
twenty-odd modules on it, four ever did: workspaces, mode, scratchpad and the
window title. Those arrive from the session through **`den.session.bar`**, keyed
by desktop id exactly like `den.session.anchors`:

```nix
# session/sway/waybar.nix
den.session.bar.sway = {
  modules = [ "sway/workspaces" "sway/mode" "sway/scratchpad" "sway/window" ];
  settings = { "sway/window".max-length = 45; /* ... */ };
};
```

`modules` leads `modules-left`; `settings` merges over the shared bar. Everything
else — GPU, temperature, weather, clock, tray, the swayidle toggle — is written
once and read by every session.

**Each entry gets a config and a systemd user unit of its own**, started by that
session's anchor and nothing else. That is forced by Home Manager, not chosen:
`programs.waybar` writes exactly one `waybar/config` and one `waybar.service`,
and `systemd.targets` is a list of targets that all start *the same process with
the same config*. One config cannot serve two compositors — Waybar logs
`Disabling module "{}", {}` for anything it cannot create and carries on with a
gap in the bar, which is a silent failure of the sort this repo keeps rejecting.
So the module sets `systemd.enable = false`, leaves `settings` at its default so
no `waybar/config` is written (Home Manager skips the file when it is empty),
keeps only the package and the stylesheet, and generates the pair per entry.

Three things that follow, and are easy to undo by accident:

- **The unit names its anchor and nothing else.** Home Manager's own unit is
  also `WantedBy=tray.target`, which is shared across the home: a tray applet
  starting in one session would pull in *every* session's bar. `session-anchors`
  asserts the `WantedBy` list equals `[ anchor ]`, so re-adding it fails there.
- **`ExecStart` names store paths**, not `~/.config`. The files under
  `waybar/<id>.json` are written all the same, for running a bar by hand.
- **The stylesheet stays shared, dead selectors and all.** `#workspaces`,
  `#mode`, `#scratchpad` and `#window` are the ids whichever compositor supplies
  those modules — niri's workspaces module carries the same
  `button.focused/.active/.urgent` classes — and a rule matching no widget costs
  nothing. Splitting the CSS per session would cost the ability to read the bar's
  colour scheme in one place, which **Colour in the bar** below depends on.

A session that ships its own shell contributes no entry and gets no bar, with no
gating needed anywhere: the renderer maps over `den.session.bar`, which is empty.

## GPU metrics in the bar

`custom/gpu` (`features/desktop/waybar.nix`) is one widget for however many GPUs
the host has, of whatever make — zuko's Intel iGPU and NVIDIA dGPU side by side,
katara's single AMD APU alone. It replaced a `custom/intel-gpu` and a
`custom/nvidia-gpu` that were each hardcoded to one vendor's tool, so katara
carried two permanently-empty widgets polling every 5s.

`nvtop -s` emits one JSON shape for every backend, which is what collapses the
two scripts into one — `print_snapshot` (`src/interface.c`) prints the same
fields out of `dynamic_info` whichever backend filled them, so every vendor
takes one code path. That derivation lives in **`self.lib.nvtop`**
(`features/system/nvtop.nix`) rather than in the bar file, because
`bundle-base` also puts it on `$PATH` for interactive use and the two must be
the same store path — a bare `nvtop` in `home.packages` would be stock
`nvtopPackages.full`, which is the CUDA build below.

**`nvtopPackages.full` is affordable only by answering `cudatoolkit` with
nothing:**

```nix
pkgs.nvtopPackages.full.override { cudatoolkit = null; }
```

That argument carries no default — only the family booleans do — so `callPackage`
fills it from `pkgs.cudatoolkit` and it has to be overridden rather than dropped.
`null` is what stdenv documents for an absent dependency
(`isSingularDependency`, `pkgs/stdenv/generic/make-derivation.nix`), and it beats
a `pkgs.emptyDirectory` stub on the one axis that matters here: if nixpkgs ever
interpolates the argument (`-I${cudatoolkit}/include`), `null` fails loudly where
an empty directory would quietly produce a flag pointing at nothing.

There is deliberately no `nvidia = true` beside it: `nvidia ? false` is the
default of `build-nvtop.nix`, but `full` is `callPackage ./build-nvtop.nix defaultSupport`, and `defaultSupport` turns on every default family — NVIDIA
included — on Linux. Setting it changes nothing (verified: byte-identical store
path), so `cudatoolkit` is the only thing this repo actually overrides.

Stock `nvtopPackages.full` on this pin is 22 derivations to build plus 2.0 GiB
to download (3.3 GiB unpacked), because `cudatoolkit` pulls `cuda-merged`. And
it is worse than merely large: CUDA is unfree, so the booted-VM session test —
which sets no `allowUnfree` — fails to **evaluate**, not merely to build. Note
that tracking nixpkgs does not fix this. [PR #521327](https://github.com/NixOS/nixpkgs/pull/521327)
already narrowed master to `cudaPackages.cuda_nvml_dev` (2026-05-17, not on our
`nixos-26.05` pin), but that package is `CUDA EULA` / `free = false` too, so the
eval wall stands either way.

Answering it with nothing is safe because **nvtop needs no CUDA at all** — this is a nixpkgs
packaging artifact, not an upstream requirement. `extract_gpuinfo_nvidia.c`
includes no NVML header; it vendors every enum and signature itself and resolves
the library with `dlopen("libnvidia-ml.so.1")` + `dlsym`, and
[`src/CMakeLists.txt`](https://github.com/Syllo/nvtop/blob/3.3.2/src/CMakeLists.txt#L53)
under `if(NVIDIA_SUPPORT)` only adds a source file — no `target_link_libraries`,
no `find_package`, and no mention of CUDA anywhere in the build files. What
*does* matter is `addDriverRunpath`, which nixpkgs applies when `nvidia = true`
and which is how the `dlopen` finds `/run/opengl-driver/lib`. Measured against
`nvidia = false`: identical 54.8 MiB closure, the same four references, zero
cuda paths, and `RUNPATH` gaining `/run/opengl-driver/lib` at the front. If
nixpkgs ever genuinely links NVML this breaks the build loudly rather than
mis-reporting, which is the failure mode to want.

Two consequences of dropping the old `nvidia-smi` branch, which used to supply
the NVIDIA numbers: the script no longer needs `/run/current-system/sw/bin` on
`PATH` (nvidia-smi ships with the driver, not a package, so it was only ever
reachable there), nor the MiB→bytes fixup (nvidia-smi reported MiB where nvtop
reports bytes). Power now reads a whole watt, since nvtop does `power_draw / 1000` in integer math where nvidia-smi gave decimals — consistent with the AMD
and Intel readings, which were always integers.

**The NVIDIA path is only testable on zuko.** katara has no discrete card, so
`nvtop -s` there proves the mesa side and nothing more. The failure mode if NVML
is unreachable is silent: nvtop skips the backend and the dGPU simply drops out
of the widget, so confirm with `nvtop -s` on zuko rather than assuming.

nvtop's Intel backend reads DRM fdinfo, not perf counters, so the bar no longer
needs `intel_gpu_top` or its `CAP_PERFMON` wrapper. zuko still sets
`hardware.intel-gpu-tools.enable`; that is now only for running `intel_gpu_top`
by hand.

The widget hides itself when every GPU reads 0%, so an idle machine shows
nothing rather than a row of zeroes.

**Colour means vendor, never load.** Each GPU's icon and percentage sit
together inside one Pango `<span>` — green NVIDIA, blue Intel, peach AMD,
`@text` for anything unrecognised — so on zuko you can tell at a glance which
number is the dGPU. The icon is repeated per GPU rather than shared, because a
single leading icon would have to take one vendor's colour and would then
contradict the reading beside it.
Load signals on a *different channel*: a coloured `border-bottom` driven by the
module class, with the base rule carrying a transparent 2px border so the label
does not shift when one appears.

AMD is `@peach` rather than the red its brand suggests, because `@red` is what
every alert in this bar already means (`#custom-temp.critical`, battery). The
underline alone would have kept the two apart, but a vendor colour that is not
also the alert colour costs nothing.

Two things follow from using markup at all. Pango colours set in a span beat
anything CSS says, so re-adding a `color:` rule for `#custom-gpu.critical` would
silently do nothing — that is why the alert is a border. And device names must
go through jq's `@html`: waybar renders the tooltip as markup too, and a name
containing `&` would otherwise make Pango reject the whole string and blank the
widget. `pango-view -q --markup` is the quick way to check a change still
parses.

The vendor literals live in `gpuVendorColors` in the same file, mirroring the
`@define-color` block, because markup cannot reference CSS colour names.

## Colour in the bar

One rule, and the GPU widget above is what forced it: **`@red` and `@yellow`
mean attention and nothing else.** Every other colour is identity. So
`sway/mode` is `@peach` rather than red (a mode is a state you are in, not
something wrong), and `#privacy` — visible only while the mic or camera is live
— is red because it genuinely is an alert.

The three load metrics (`#cpu`, `#memory`, `#custom-temp`) are deliberately
uncoloured, taking `@text` from the global module rule, and colour only when
they cross a threshold. Temperature used to be `@peach` full-time, which both
broke that symmetry and put a second peach next to the GPU widget's AMD reading.
Note the states come from the modules themselves: `cpu` and `memory` declare
`states`, while `custom/temp` emits its own class — its `warning` at 60 °C had
no CSS rule for a while, so 60–79 °C looked identical to idle.

Neighbours must not share a hue family, which is the whole reason `#wireplumber`
is `@mauve` (it sits immediately right of the GPU) and `#power-profiles-daemon`
moved to `@teal` to make room. Colours still repeat *across* regions —
`@lavender` on scratchpad, clock and the idle inhibitor; `@mauve` on mpris and
wireplumber; `@teal` on weather and ppd — which is fine, as they are never
adjacent.

Icons get checked the same way, by rendering rather than by reading codepoints:

```bash
pango-view -q --font "JetBrainsMono Nerd Font 13" --background "#1e1e2e" \
  --markup --text '󰘚 42%  󰍛 61%' -o /tmp/bar.png
```

At 13 px the nf-md cpu glyph and the memory glyph are both a gear-in-square and
were indistinguishable, with the two modules adjacent; `#cpu` uses a
chip-with-pins now. Anything added to the bar is worth one render at 13 px
before trusting it.
