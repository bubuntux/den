# Desktop sessions

How a bare compositor is started, scoped, and what it has to declare. The bars and
terminals it drives are in `../AGENTS.md`; repo-wide rules and the
`den.desktop` profile-vs-host table are in the root `AGENTS.md`.

## Session scoping

**There is deliberately no per-user desktop selection.** Installing an environment configures it for *every* user on the host (`home-manager.sharedModules`), so whichever session someone picks at the greeter is one their home is set up for. Naming one desktop per person cannot work: the greeter offers every installed session to everyone regardless, so all such an option decides is whose home is *unprepared* for the session they chose.

What makes one home holding several desktops work is that nothing a session owns may be home-wide. Anything that would be gets scoped, in one of two ways.

**User units** name the session they belong to:

- **`den.session.anchors`** (`features/desktop/session/options.nix`, per user) — desktop id → the unit that means "this session is running", contributed by each session module. `homeManager.sway` publishes `sway = "wayland-session@sway.target"`. Keyed by id (the lowercased name in `XDG_CURRENT_DESKTOP`, used for per-desktop files below) rather than a bare list. Key and value can disagree on more than shape — Hyprland's are `hyprland` and `wayland-session@Hyprland.target` — see **Adding a desktop environment**.
- **`den.desktop.sessionAnchors`** (`features/desktop/options.nix`, per host) — the same fact system-side, for system-level user units (`blueman-applet`) and as the gate for "does any installed session need the companion stack" (`nixos.thunar`, `nixos.session-wayland`). A session that ships its own shell publishes nothing (GNOME has no entry).
- **`den-session.target`** (`session/wayland.nix`) — one unit for shared companions, started by *any* anchor and stopped with it. `wayland.systemd.target` points at it, so upstream Home Manager modules (kanshi, swayidle, clipman, dunst…) bind there automatically.

Nothing a session owns may bind to `graphical-session.target`: **every** desktop starts it, GNOME included (a companion bound there follows the user into GNOME). `session-anchors` enforces this.

**Config files** read by name (`~/.config/sway/config`) are already scoped. Shared files use per-desktop variants or a least-wrong tie-break:

- **`<desktop>-mimeapps.list`** (`features/desktop/thunar.nix`) — XDG reads `$XDG_CONFIG_HOME/<desktop>-mimeapps.list` before `mimeapps.list`, letting folders open in thunar under Sway and nautilus under GNOME out of one home. Home Manager's `xdg.mimeApps` only writes the shared list, so this is a hand-written `xdg.configFile`.
- **No per-desktop form**: settle once for the home as "least wrong in the desktop that did not ask for it" (`xdg.userDirs.desktop` stays for GNOME even though Sway doesn't need it).

**Wiring rules:**

- **Desktop Home Manager modules reach users through `den.desktop.environments`**, which pushes them at `home-manager.sharedModules`, never from the user module — `user-bbtux` is shared with headless `appa`, which must not grow a desktop. Everything a session owns sits behind `homeManager.session-wayland` and an anchor (including modules outside `features/desktop/`).
- **A session's `imports` are NOT covered by its `mkIf`.** `bundle-desktop` imports every session unconditionally and relies on each keeping its config under `lib.mkIf (lib.elem "<name>" …)`. `imports` sits outside that, so imported modules land on hosts that never selected the session unless they attach per user (HM) or gate themselves (`nixos.thunar` and `nixos.session-wayland` gate on `config.den.desktop.sessionAnchors != { }`).
- **A host writing an option through `home-manager.sharedModules` must declare it there too** (e.g., `hosts/*/monitors.nix` imports `monitors` schema alongside values so it exists on hosts with no session reading it).

## How a bare session starts (uwsm)

A compositor on its own gives you windows and nothing else: no session target to
bind helpers to, no XDG autostart, and no environment in the systemd user
manager. Every compositor solves that differently or not at all — Sway only had
it through Home Manager, and **mangowc ships nothing** — so all of them run through
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
  entry at all — the geoclue agent — are bound explicitly.
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

Read `session/sway/default.nix` alongside this. The steps are each small, but missing
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
   For packages built as a plain derivation where modifying the build would recompile
   from source, wrap in a `pkgs.symlinkJoin` instead:

   ```nix
   package = pkgs.symlinkJoin {
     name = "<name>-uwsm-session-${pkgs.<name>.version}";
     paths = [ pkgs.<name> ];
     inherit (pkgs.<name>) meta passthru;   # providedSessions lives in passthru
     postBuild = ''rm $out/share/wayland-sessions/<name>.desktop && cat > ... '';
   };
   ```

   `lndir` gives real directories with symlinked leaves, so `rm` then `cat` works.
   Carry `passthru` across or `services.displayManager.sessionPackages` rejects the
   package: it validates against `passthru.providedSessions`.

   The session environment (toolkit variables and the like) goes **here** when the
   compositor's NixOS module offers a hook for it, because uwsm starts the system
   binary by absolute path and anything set in a Home Manager wrapper never runs.
   `programs.sway` has `extraSessionCommands`; for compositors with no equivalent,
   variables go in `~/.config/uwsm/env-<name>`, which uwsm's env preloader sources.

1. **Home Manager half:**

   ```nix
   imports = with self.modules.homeManager; [ session-wayland session-options ];

   den.session.anchors.<name> = "wayland-session@<id>.target";
   ```

   plus the compositor's config, with its package set to `null` and its own
   systemd/session integration turned off, and `uwsm finalize <VARS>` as the
   **first** startup command. If Home Manager has no module for the compositor,
   the config is a hand-written file under `xdg.configFile`; write it as
   **`.text`, not a `writeText` `source`**, so a check can read what is in it
   without building anything.

1. **Give it a bar.** Whichever renderer the host picked, the compositor's IPC
   socket has to reach the systemd user environment through `uwsm finalize`, the
   way `SWAYSOCK` does. Then:

   - **waybar** needs a file next to the session's own contributing
     `den.session.bar.<name>`, imported by the Home Manager half (see **One bar
     per session**). Skipping it is legal but leaves the session with no
     workspaces and no window title.
   - **ironbar** needs nothing, because it detects the compositor itself — but
     check it against `supportedBy` in `features/desktop/ironbar.nix`: a session
     ironbar cannot drive silently drops `workspaces` from *every* host that
     installs it. Extend that attrset rather than the module list.

1. **Host:** add `"<name>"` to `den.desktop.environments` (usually via a
   profile). To preselect it under greetd, `services.displayManager.defaultSession = "<name>"`. Under **GDM, leave `defaultSession` unset** — see below.

1. **Prove it boots.** `mkSessionTest` in `modules/core/tests.nix` takes a
   `session` argument, so this is one more entry in `packages` — `nix flake check`
   will not tell you a session comes up.
   See **Booted-VM tests** in `modules/core/AGENTS.md`.

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

## Session Layout

A session that brings companion pieces becomes a directory, so the tree says who owns what. GNOME needs none (it keeps its state in GSettings and mutter manages its own outputs), so it stays a single file; Sway carries the pieces that speak its IPC:

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
```

The test for whether something belongs in `session/<name>/` is whether it names the compositor. Anything DE-agnostic stays out of it: `ghostty` and `foot` are terminals the host picks between with `den.desktop.terminal` (see **Choosing a terminal** in `../AGENTS.md`), `thunar` a file manager, `kanshi` drives outputs over `wlr-output-management` (which any compositor here speaks), `waybar` and `ironbar` are bars that learn the compositor from `den.session.bar` and from the environment respectively (see **Choosing a bar**, same file), `bar-scripts` holds the two readings they share, and `monitors` only declares the schema hosts write their display layout in. Those all sit flat under `features/desktop/`.

`session/wayland.nix` is where that rule leads for a *group* of them. Notifications, launcher, locker, idle handling, colour temperature, keyring and tray applets are each DE-agnostic, but they only make sense together — no host wants a subset — so they are one module ("the parts a compositor omits") rather than nine files. Sway's own copies of these were what made the first attempt at a second session look expensive.

Where such a feature gets imported *from* is the separate question, and the answer is not automatically `bundle-desktop`: that bundle is for what every environment on the host should have. A per-session choice belongs to the session — `session-wayland` is imported by `sway`, not the bundle, so a GNOME user on the same host keeps nautilus and one network applet rather than being handed both. When the choice is system-level rather than per-user, the imported module has to gate itself; see the `imports`/`mkIf` bullet above.
