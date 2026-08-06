# Desktop sessions

How a bare compositor is started and what it has to declare. The bars and
terminals it drives are in `../CLAUDE.md`; the `den.desktop` option table and the
session-scoping rules are in the root `CLAUDE.md`.

## How a bare session starts (uwsm)

A compositor on its own gives you windows and nothing else: no session target to
bind helpers to, no XDG autostart, and no environment in the systemd user
manager. Every compositor solves that differently or not at all — Sway only had
it through Home Manager, niri ships `niri.service`, and **mangowc ships
nothing** — so all of them run through
[uwsm](https://github.com/Vladimir-csp/uwsm) instead, which makes it one answer:
`wayland-session@<id>.target`, where the id is the basename of the compositor
binary.

That splits ownership three ways, and the split is the part worth remembering:

| piece | owner |
|---|---|
| the binary, and the session environment it exports | `programs.sway` (NixOS) — `wrapperFeatures`, `extraOptions`, `extraSessionCommands` |
| the compositor's own config | `wayland.windowManager.sway` (Home Manager), with **`package = null`** |
| starting it, and the units around it | `programs.uwsm` |

Home Manager sets `package = null` because uwsm starts
`/run/current-system/sw/bin/sway` by absolute path, so the system wrapper is the
only one that ever runs — upstream documents exactly this pairing. It also
settles an ambiguity that predates uwsm: both modules used to build a wrapper,
they differed, and which one you got came down to PATH order.

Two things are load-bearing and easy to omit:

- **`uwsm finalize` must run inside the compositor.** `wayland-wm@<id>.service`
  is `Type=notify`, so without it the unit never reports ready and systemd kills
  the session after 30s. It also carries the variables that must reach the
  systemd/dbus user environment — `SWAYSOCK` above all, which is how Waybar
  finds the compositor.
- **Session commands with spaces must be quoted.** `den.desktop.sessionCommands`
  entries end up inside tuigreet's `--cmd`, which takes a single argument;
  `login/greetd.nix` runs them through `lib.escapeShellArg` for that reason.
  Nothing noticed while every command was a bare `sway`, and `uwsm start -F -- …` is what broke it.

**There must be exactly one session entry per compositor, and it must start
uwsm.** nixpkgs' `programs.<name>` registers the compositor's own entry in
`services.displayManager.sessionPackages`, and there is no supported way to
withdraw it — so `programs.uwsm.waylandCompositors`, which generates a *second*
entry called "<Name> (UWSM)", leaves the plain one sitting next to it in the
greeter. That one starts a compositor with no anchor: no bar, no idle handling,
no output management. A menu entry that yields a broken session is worse than a
rename, so the compositor's own entry gets rewritten instead:

```nix
package = pkgs.sway.overrideAttrs (old: {
  buildCommand = old.buildCommand + ''
    rm -f $out/share/wayland-sessions/sway.desktop
    cat > $out/share/wayland-sessions/sway.desktop <<'EOF'
    ...
    Exec=${lib.getExe pkgs.uwsm} start -F -- /run/current-system/sw/bin/sway
    EOF
  '';
});
```

Two things that bit while writing that. It has to append to **`buildCommand`**,
not `postBuild`: the wrapper is a `symlinkJoin`, which interpolates its
`postBuild` argument into the build script rather than passing it to
mkDerivation, so an `overrideAttrs` on `postBuild` sets an attribute nothing
reads — and `old.postBuild or ""` would hide that. And `programs.sway.package`
has an `apply` that re-runs `.override` with the module's wrapper options;
`overrideAttrs` does survive it, but that was worth checking rather than
assuming.

The session keeps the plain id (`sway`), so hosts preselect `"sway"` and
`den.desktop.sessionCommands.sway` carries the same uwsm command the entry does.

`programs.uwsm.enable` is set once, by `nixos.session-wayland`, since it is the
same answer for every bare session and that module already means "something
installed here ships no shell of its own". A session module only registers its
own compositor.

### XDG autostart

uwsm brings `wayland-session-xdg-autostart@<id>.target`, so `/etc/xdg/autostart`
entries now run in a bare session the way they do in a full desktop. That
changed two things and is worth knowing before wiring anything by hand:

- **Anything with an autostart entry needs no wiring from us.** `blueman-applet`
  used to be bound to the anchors here because a bare Sway had no autostart; once
  uwsm arrived that became a *second* copy of the applet. Only things with no
  entry at all — the geoclue agent, the idle inhibitor — are bound explicitly.
- **Entries meant for "any desktop but GNOME" now apply.** `ibus-daemon.desktop`
  is `NotShowIn=GNOME;KDE`, so installing GNOME on a host puts IBus in the Sway
  session, notification and all. `session/wayland.nix` hides it with a user-level
  entry carrying `Hidden=true`, which systemd's generator honours alongside
  `OnlyShowIn`/`NotShowIn`. GNOME is unaffected: it starts ibus from gnome-shell,
  not from autostart.

### Monitors and kanshi

kanshi activates a profile only when the connected output **set** exactly equals
the profile's, which drives two things in `features/desktop/kanshi.nix` that look
odd in isolation:

- **Every profile must account for the internal panel.** Profiles that don't use
  it list it as `status = "disable"`, which both lets a docked profile match and
  keeps the laptop screen off while docked. External-only profiles therefore
  expand to *two* variants: `<name>` (panel connected, disabled) and
  `<name>-no-panel`, because on a lid-closed boot i915 drops the eDP connector
  entirely ("unusable PPS, disabling eDP") and a profile naming eDP-1 can never
  match then.
- **kanshi is enabled only for a user who has `monitors`.** With none, Home
  Manager writes no config file at all, kanshi exits 1 on "failed to parse config
  file", and `Restart=always` turns that into a crash loop ending in `failed`.
  Every host ships a `monitors.nix`, so this only bites a new one — which is
  exactly how the session VM test found it.

### Keyring

PAM unlocks a gnome-keyring daemon with the login password (greetd and GDM both
do), but PAM runs before the user dbus socket exists, so that daemon never claims
the session bus and then dies — and the first libsecret app dbus-activates a
fresh, *locked* one, which is a password prompt out of nowhere. The user service
in `session/wayland.nix` runs `gnome-keyring-daemon --start` while the PAM daemon
is still alive, so it adopts that unlocked daemon and claims the bus. It stays on
`graphical-session-pre.target` rather than a session anchor, because it has to be
up before anything asks for a secret; `--start` adopts rather than duplicates, so
it is harmless in a session that already has one.

## Adding a desktop environment

There are two worked examples now, and they differ in the two places that matter
most, so read whichever is closer: **sway** has a Home Manager module for its
config and a nixpkgs *wrapper* for its package, while **niri** has neither — see
**The niri session** below for what that costs. Read `session/sway/default.nix` or
`session/niri/default.nix` alongside this. The steps are each small, but missing
one tends to fail at login rather than at evaluation.

1. **Name it.** Add `"<name>"` to `sessionNames` in `features/desktop/options.nix`.

1. **Create `features/desktop/session/<name>.nix`** — a directory if it grows
   compositor-specific companions, see **Session Layout**. Both halves keep all
   config under `lib.mkIf (lib.elem "<name>" config.den.desktop.environments)`.

1. **Import it from `bundle-desktop`.**

1. **NixOS half:**

   ```nix
   imports = with self.modules.nixos; [ desktop-options session-wayland ];

   programs.<name>.enable = true;
   # ... and rewrite the session entry that ships with it so it starts uwsm,
   # rather than adding a second one with programs.uwsm.waylandCompositors.
   # See "How a bare session starts" above for why, and for the buildCommand
   # -vs- postBuild trap. A compositor that ships no entry of its own is the
   # one case where waylandCompositors is the right tool.
   programs.<name>.package = <see below>;

   den.desktop.sessionAnchors.<name> = "wayland-session@<id>.target";
   den.desktop.sessionCommands.<name> =
     "${lib.getExe pkgs.uwsm} start -F -- /run/current-system/sw/bin/<binary>";
   ```

   **How to rewrite that entry depends on what the package is, and getting it
   wrong costs a full rebuild rather than an error.** sway's `programs.sway.package`
   is a `symlinkJoin` wrapper, so appending to its `buildCommand` is nearly free.
   niri's is `rustPlatform.buildRustPackage` — an `overrideAttrs` on `postInstall`
   there would recompile the whole compositor from source to change one 6-line
   text file. So niri wraps instead:

   ```nix
   package = pkgs.symlinkJoin {
     name = "niri-uwsm-session-${pkgs.niri.version}";
     paths = [ pkgs.niri ];
     inherit (pkgs.niri) meta passthru;   # providedSessions lives in passthru
     postBuild = ''rm $out/share/wayland-sessions/niri.desktop && cat > ... '';
   };
   ```

   `lndir` gives real directories with symlinked leaves, so `rm` then `cat` works.
   Carry `passthru` across or `services.displayManager.sessionPackages` rejects the
   package: it validates against `passthru.providedSessions`.

   The session environment (toolkit variables and the like) goes **here** when the
   compositor's NixOS module offers a hook for it, because uwsm starts the system
   binary by absolute path and anything set in a Home Manager wrapper never runs.
   `programs.sway` has `extraSessionCommands`; **`programs.niri` has no
   equivalent**, so niri's go in `~/.config/uwsm/env-niri`, which uwsm's env
   preloader sources — see **The niri session**.

1. **Home Manager half:**

   ```nix
   imports = with self.modules.homeManager; [ session-wayland session-options ];

   den.session.anchors.<name> = "wayland-session@<id>.target";
   ```

   plus the compositor's config, with its package set to `null` and its own
   systemd/session integration turned off, and `uwsm finalize <VARS>` as the
   **first** startup command. If Home Manager has no module for the compositor —
   which is niri's case on the `release-26.05` pin — the config is a hand-written
   file under `xdg.configFile`; write it as **`.text`, not a `writeText` `source`**,
   so a check can read what is in it without building anything.

1. **Give it a bar.** Whichever renderer the host picked, the compositor's IPC
   socket has to reach the systemd user environment through `uwsm finalize`, the
   way `SWAYSOCK` does — niri's is `NIRI_SOCKET`. Then:

   - **waybar** needs a file next to the session's own contributing
     `den.session.bar.<name>`, imported by the Home Manager half (see **One bar
     per session**). Skipping it is legal but leaves the session with no
     workspaces and no window title.
   - **ironbar** needs nothing, because it detects the compositor itself — but
     check it against `supportedBy` in `features/desktop/ironbar.nix`: a session
     ironbar cannot drive silently drops `workspaces` from *every* host that
     installs it, and one it drives only partly (niri, no `bindmode`) drops that
     module for everyone. Extend that attrset rather than the module list.

1. **Host:** add `"<name>"` to `den.desktop.environments` (usually via a
   profile). To preselect it under greetd, `services.displayManager.defaultSession = "<name>"`. Under **GDM, leave `defaultSession` unset** — see below.

1. **Prove it boots.** `mkSessionTest` in `modules/core/tests.nix` takes a
   `session` argument, so this is one more entry in `packages` — `nix flake check`
   will not tell you a session comes up. Then **look at the screenshot**: a
   compositor with no software-rendering fallback passes every unit assertion
   while drawing nothing at all, which is exactly what `test-session-niri` does.
   See **Booted-VM tests** in `modules/core/CLAUDE.md`.

Five things that are easy to get wrong, in the order they bite:

- **The id is the binary's basename, not your session name.** Hyprland's binary
  is `Hyprland`, so its anchor is `wayland-session@Hyprland.target`. Confirm
  with `uwsm start -n -o -F -- <binPath>`, which prints "Selected compositor ID"
  and "Initial Desktop Names" without touching anything. Run it with
  `env -u XDG_CURRENT_DESKTOP -u SWAYSOCK`: inside a live session it reports the
  *current* desktop's names rather than the ones the new session would get, which
  reads exactly like a bug in the thing you are adding.
- **The anchor *key* names files, the *value* names a unit.** `thunar.nix`
  builds `<key>-mimeapps.list` from `den.session.anchors`, and XDG lowercases
  the desktop name when it looks that file up. So the key is the lowercased id
  and the value keeps the real unit name — `hyprland = "wayland-session@Hyprland.target"`.
  They coincide for Sway, which hides the distinction. Check a live session with
  `systemctl --user show-environment | grep XDG_CURRENT_DESKTOP`.
- **`uwsm finalize` is mandatory.** `wayland-wm@<id>.service` is `Type=notify`;
  without it the session is killed after 30s. Name every variable that must
  reach the systemd/dbus user environment — anything a user service needs, the
  compositor's IPC socket above all.
- **`sessionCommands` is keyed by *session*, and the session is whatever the
  entry file is called.** Rewriting the compositor's own entry keeps that
  `<name>`; adding one through `programs.uwsm.waylandCompositors` would make it
  `<name>-uwsm`. Key it wrong and greetd silently has nothing to preselect.
- **`services.displayManager.defaultSession` is not a default under GDM.**
  nixpkgs turns it into a `set-session` call in GDM's preStart, whose own
  comment reads "basically ignore session history" — it rewrites *every* user's
  remembered session on each boot. Leave it unset on a GDM host (katara does);
  only greetd and autologin actually need it.

A session that ships its own shell (GNOME) skips all of this: no uwsm entry, no
anchors, no `session-wayland`, no session command.

## The niri session

katara's third session, and the second bare compositor. **It is on trial**, which
is why `den.desktop.environments = [ "niri" ]` sits in `hosts/katara/default.nix`
rather than in a profile: the option merges, so a host can add one on top of what
its roles install, and zuko shares `profile-workstation` and should not pay for
this. Move it into a profile if and when it stops being an experiment.

**The keybindings are deliberately upstream's**, transcribed from niri's own
`resources/default-config.kdl` (in the package's `doc` output) with four changes
and no more: the terminal and launcher spawn what this repo installs, the lock key
goes through logind, and the orca screen-reader bind is dropped because orca is not
installed and a bind to a missing binary is the silent-failure shape this repo
rejects. So **`Mod+T` opens a terminal and `Mod+Q` closes a window** — niri's
bindings, not sway's `Mod+Return`/`Mod+Shift+Q`. Do not "fix" that to match sway
without being asked; it is the point of the first pass.

Eight things about this session that are not visible in the file:

- **Home Manager has no niri module on the `release-26.05` pin.** `wayland.windowManager.niri`
  exists upstream but not here, so the whole session config is one hand-written KDL
  string in `_config.nix`. Two consequences: it is written as `xdg.configFile.<n>.text`
  rather than a `writeText` `source`, so `terminal-choice` can grep it for free; and
  it gets its own `niri-config` check, because a typo there does not fail evaluation
  — niri falls back to its built-in defaults and you find out at login. Revisit all
  of this when the pin gains the module.

- **Nothing sets outputs, on purpose.** kanshi owns them for every session here, and
  niri really does implement `zwlr_output_manager_v1` (`src/protocols/output_management.rs`,
  including `CreateConfiguration`, so it is writable and not just introspection). It
  reports `make`/`model`/`serial_number` per head, which is what katara's
  identity-keyed profiles ("Dell Inc. DELL U2722DE J85KV83") match on. Note niri
  reports the head *name* as make-model-serial too when it has them
  (`format_make_model_serial_or_connector`), where sway reports the connector — so
  `niri msg outputs` reads differently from `swaymsg -t get_outputs`. An `output`
  node in the config would fight kanshi rather than help it.

- **niri draws no wallpaper**, where sway has `output "*" bg`. So one layer-shell
  client supplies it, as a user unit anchored to niri — `wbg` rather than `swaybg`:
  same protocol, 20 KiB, and no sway in the closure. `session-anchors` pins its
  `WantedBy`, and `test-session-niri` includes it in the `NRestarts` set, since a
  wallpaper that died is the one companion whose failure looks like the compositor's.

- **The lock key names logind, not a locker.** `spawn "loginctl" "lock-session"`
  fires the Lock signal that `services.swayidle` in `session/wayland.nix` already
  handles, so the niri config never mentions swaylock. That keeps the choice of
  locker in one place for every session — and swaylock does work here (niri serves
  `ext-session-lock-v1`), it just is not niri's business which one it is.

- **`programs.niri` has no `extraSessionCommands`**, so the toolkit variables sway
  gets from its wrapper go in `~/.config/uwsm/env-niri` instead, which uwsm's env
  preloader sources: `libexec/uwsm/prepare-env.sh` walks every config dir and, per
  dir, sources `uwsm/env` then `uwsm/env-<name>` (plus `.d/` directories) **for each
  lowercased entry of `XDG_CURRENT_DESKTOP`** — not the uwsm compositor id. Those
  coincide for niri; they would not for Hyprland, whose id is `Hyprland` and whose
  file is `env-hyprland`. Same trap as the anchor key naming `<desktop>-mimeapps.list`.
  `env-niri` and not `env`: the file is home-wide like everything Home Manager
  writes, and only the per-desktop name keeps it out of a GNOME login in the same
  home.

- **X11 goes through `xwayland-satellite`**, pinned by store path in the config
  because niri's default is a bare name on `PATH` and a lookup that misses disables
  X11 with nothing but a journal line.

- **`prefer-no-csd` is set, and it is what makes ghostty behave.** ghostty asks the
  compositor for decorations (`window-decoration = server`, see **Choosing a
  terminal**), and niri serves `org_kde_kwin_server_decoration` — so without this
  every window in a tiling session would carry a GTK headerbar. It is not a
  keybinding, which is why it is set despite the vanilla-first rule.

- **Screen capture is the GNOME portal, not wlr.** niri implements the GNOME
  screencast D-Bus API — that is its `xdp-gnome-screencast` build feature — so
  `xdg.portal.config.niri` points ScreenCast and Screenshot at `gnome`, mirroring the
  `niri-portals.conf` the package ships. `useNautilus = false` keeps FileChooser on
  gtk, which is what `session/wayland.nix` already asks for and what a session using
  thunar wants.

Two loose ends worth knowing rather than fixing:

- **`swayidle` now carries both compositors' blanking commands.** It is one unit on
  `den-session.target`, and each session appends its own timeout — `swaymsg 'output * power off'`
  and `niri msg action power-off-monitors` — so on katara both fire at 360s and the
  one whose socket is absent exits non-zero and does nothing. Harmless, and noisy in
  the journal. The clean fix is a per-session idle-command registry keyed like
  `den.session.anchors`; not worth it for one line until a third bare session shows up.
- **ironbar loses its mode indicator on any host that installs niri.** `bindmode` is
  sway/hyprland only, and `supportedBy` in `features/desktop/ironbar.nix` drops a
  module the moment one installed session cannot back it. That was predicted in
  **Choosing a bar** (`../CLAUDE.md`) before niri existed, and it is now what actually happens on
  katara. waybar is unaffected — it builds one bar per session.

The package's own `niri.service` and `niri-shutdown.target` are installed by
nixpkgs' `systemd.packages` and are inert: `niri.service` has no `[Install]`
section, so nothing pulls it in, and only `niri-session` would have started it.
That is fine to leave alone — but it is also why the shipped `Exec=niri-session`
desktop entry has to be rewritten rather than kept: it binds the session to
`graphical-session.target`, which is precisely the target no companion here follows.

## Session Layout

A session that brings companion pieces becomes a directory, so the tree says who owns what. GNOME needs none (it keeps its state in GSettings and mutter manages its own outputs), so it stays a single file; Sway and niri carry the pieces that speak their IPC:

```
modules/features/desktop/session/
  options.nix           # den.session.* -- the user-scoped session schema
  wayland.nix           # what a bare compositor omits, for every such session
  gnome.nix             # one file is enough
  sway/
    default.nix         # nixos.sway + homeManager.sway
    waybar.nix          # den.session.bar.sway -- the four sway/* modules only
    dictation.nix       # writes wayland.windowManager.sway.config.keybindings
    _keybindings.nix    # `_` fragments: curried functions, not flake-parts
    _modes.nix          #   modules, imported by ./default.nix
    _rules.nix
    _startup.nix
  niri/
    default.nix         # nixos.niri + homeManager.niri
    waybar.nix          # den.session.bar.niri -- niri/workspaces and niri/window
    _config.nix         # the whole config.kdl, as one curried function
```

niri's config is *one* fragment where sway has four, and that is the shape of the
difference rather than a stylistic choice: sway's config is an attrset the Home
Manager module merges, so splitting it costs nothing, while niri's is a single KDL
string on this pin and splitting it would just be string concatenation.

The test for whether something belongs in `session/<name>/` is whether it names the compositor. Anything DE-agnostic stays out of it: `ghostty` and `foot` are terminals the host picks between with `den.desktop.terminal` (see **Choosing a terminal** in `../CLAUDE.md`), `thunar` a file manager, `kanshi` drives outputs over `wlr-output-management` (which any compositor here speaks — niri included), `waybar` and `ironbar` are bars that learn the compositor from `den.session.bar` and from the environment respectively (see **Choosing a bar**, same file), `bar-scripts` holds the two readings they share, and `monitors` only declares the schema hosts write their display layout in. Those all sit flat under `features/desktop/`.

`session/wayland.nix` is where that rule leads for a *group* of them. Notifications, launcher, locker, idle handling, colour temperature, keyring and tray applets are each DE-agnostic, but they only make sense together — no host wants a subset — so they are one module ("the parts a compositor omits") rather than nine files. Sway's own copies of these were what made the first attempt at a second session look expensive.

Where such a feature gets imported *from* is the separate question, and the answer is not automatically `bundle-desktop`: that bundle is for what every environment on the host should have. A per-session choice belongs to the session — `session-wayland` is imported by `sway`, not the bundle, so a GNOME user on the same host keeps nautilus and one network applet rather than being handed both. When the choice is system-level rather than per-user, the imported module has to gate itself; see the `imports`/`mkIf` bullet above.
