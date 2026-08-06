# Checks and tests

What `nix flake check` verifies, and the booted-VM tests that deliberately sit
outside it. Repo-wide rules are in the root `CLAUDE.md`.

## Checks

`modules/core/checks.nix` defines what `nix flake check` verifies beyond formatting:

| check | what it proves |
|-------|----------------|
| `desktop-matrix` | nine DE/login-manager combinations produce the expected config |
| `desktop-rejects` | four invalid combinations are refused |
| `session-anchors` | a session's user units stay out of the user's other desktops, under either bar |
| `terminal-choice` | `den.desktop.terminal` installs one terminal, uninstalls the other, and both bare sessions spawn the command that one states |
| `unit-shape` | no surprise systemd directives on units this repo configures |
| `ironbar-config` | the generated ironbar config parses, per ironbar itself |
| `ghostty-config` | the generated ghostty config parses, per ghostty itself |
| `niri-config` | the generated niri config parses, per niri itself |
| `media-plumbing` | `den.media.services` really generates what it claims, for every entry |

All but the three `*-config` checks are **evaluation-only**; those run a validator
over generated files and build nothing else. Host builds deliberately do *not* live here, even though `nix flake check` is the obvious place for them: `.github/workflows/_build.yml` already builds every host in a matrix with per-host error logs, and `ci.yml` gates `build` on `check` while `heal` fires on `build` *failing*. A host build inside `checks` moves a caddy-hash drift from `build` (fails → heal runs) to `check` (fails → build skipped → heal never runs), silently disabling the caddy self-heal. Build a host by hand instead:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

The desktop checks carry the most weight, because `den.desktop`'s assertions are all that stand between a typo and a machine with no way to log in — and no host exercises the two-environment path, let alone one user carrying three, so it would rot unnoticed. They read `config.assertions` and a handful of option values rather than forcing `system.build.toplevel`, which keeps sixteen NixOS evaluations affordable (~1.5 min for the whole of `nix flake check`, uncached).

`session-anchors` covers the failure mode `desktop-matrix` structurally cannot see. Home Manager config lands in a *home*, not in a session — and since every user now gets every installed desktop, every evaluated option value can be correct while a unit is bound to `graphical-session.target`, which every desktop starts. It probes katara (all three desktops, GDM) through **shari**, who only ever logs into GNOME and is therefore where an escaping companion shows up, and asserts six things: each shared companion follows `den-session.target`, `den-session.target` itself is started by *every* anchor (miss one and that session comes up with no companions at all), every bar in `den.session.bar` has a unit whose `WantedBy` is *exactly* its own anchor, `niri-wallpaper` likewise names niri's anchor alone, `<desktop>-mimeapps.list` points folders at thunar for every bare session, and the shared `mimeapps.list` does not. It carries a second, cheap probe for the other bar — `den.desktop.bar = "ironbar"` inverts the rule, since one bar for every session must follow `den-session.target` and not an anchor — with both installed, so it also asserts the loser's units exist and are wanted by nothing. It also forces her `home.activationPackage.drvPath`, so an option two desktops define differently fails here rather than at switch time. That full Home Manager evaluation is the bulk of the check's cost; the desktop cases read `attrNames` and stay cheap.

`terminal-choice` exists because the terminal is the one thing a session names that is *not* the option's value: `den.desktop.terminal = "foot"` has to reach `Mod+Return` as **footclient**. A package list would look right in both cases, so the check reads `wayland.windowManager.sway.config.terminal` and the rofi launcher's `-terminal` argument instead, once per enum value, and asserts the losing terminal is not installed. It also pins foot's server unit to `den-session.target`, since a server bound to `graphical-session.target` would start under a GNOME login that has no foot to talk to it. Two of its four properties are guarded by the module system before the check ever runs — `den.session.terminal` has no default, so pushing no terminal module fails evaluation, and pushing two fails on conflicting definitions.

Its probes install **both** bare sessions, because niri needs the check more than sway does: sway states the terminal through a Home Manager option the module system will type-check, while niri's config is a hand-written KDL string on this pin, so there is nothing to read the command back out of. So for niri the check greps the generated text for `spawn "<command>"` — and for the *absence* of the other terminal's, since a leftover literal is exactly how that string goes wrong.

`unit-shape` exists because comparing evaluated option *values* is blind to *added* systemd directives — which is how `services.greetd.useTextGreeter` once shipped and left the greeter drawing its clock onto a console systemd had reset underneath it. It pins the set of directive *names* per section, never their values: store paths and package versions live in values, and pinning those would make the check fire on every `nix flake update`.

`media-plumbing` asserts properties over every `den.media.services` entry rather than a golden snapshot, so a service added later is covered for free. Note that `requiresMounts` is checked by *containment*, not equality — the upstream service modules add their own state directories to `RequiresMountsFor` (jellyfin contributes three).

**Adding a case** means appending to `cases` (with an `expect` attrset, and optionally `cmdContains` to assert on the greeter command line), to `rejects` (which passes when evaluation throws *or* any assertion reports false), to `unitShapes`, to `expected` in `terminalFailures` (module name → the command it states, which also adds its probe), or — for a companion that must follow the session — to `companions` in `anchorFailures`.

Note what `cmdContains` can pin beyond a store path, because the niri case leans on it: `"-- /run/current-system/sw/bin/niri'"` asserts the *closing* quote, so one string covers both that `sessionCommands` was keyed correctly (an unkeyed session silently produces no `--cmd` at all — greetd warns, it does not assert) and that the multi-word command survived `escapeShellArg` as one argument.

**When adding or changing a check, prove it bites.** Break the thing on purpose, confirm the check fails with a message that names the problem, then revert. A check that has never failed is not known to work. Every check here was validated that way: removing `den.desktop.sessionCommands.sway` made `desktop-matrix` report the missing `--cmd sway`; neutralising the "nothing can start a session" assertion made `desktop-rejects` report "was accepted, expected rejection"; dropping LightDM's `services.xserver.enable` failed on both the assertion and the expectation; re-enabling `useTextGreeter` made `unit-shape` list all seven directives it adds; breaking the registry's umask and namespace-address derivation made `media-plumbing` name the affected services.

`session-anchors` was validated four times over, once per property it holds: dropping `wayland.systemd.target` from `session/wayland.nix` made it name kanshi, swayidle and idle-inhibit-init as bound to `graphical-session.target`; giving `homeManager.gnome` its own `xdg.userDirs.desktop` made it report the conflicting definition; and moving thunar's association back into the shared `mimeapps.list` made it report that the default "would follow the user into GNOME".

`terminal-choice` was validated three times: making `homeManager.foot` state `den.session.terminal = "foot"` rather than `footclient` made it report both the wrong spawn and the wrong `-terminal` argument; dropping the terminal push from `session/wayland.nix` failed earlier still, on `den.session.terminal` having no value; and pointing foot's `server.systemdTarget` at `graphical-session.target` made it name the unit and print the target it got. Its niri half was validated by hardcoding `spawn "foot"` in `_config.nix`, which made it report both terminals as unspawned.

The niri additions were validated the same way, and one attempt failed to bite, which is worth knowing: **`niri validate` accepts a bogus argument on a bare node** — `prefer-no-csd true` passes — so that is not a usable break. A typo'd *action* is: `close-windo` made `niri-config` print "expected `quit`, `suspend`, or one of 133 others". Mis-keying `den.desktop.sessionCommands.niri` to `niri-uwsm` made `desktop-matrix` print the whole greeter command line and name the missing infix. Pointing `niri-wallpaper`'s `Install.WantedBy` at `graphical-session.target` made `session-anchors` report it twice over — once from the blanket rule, once from the unit's own assertion.

Writing `session-anchors` also showed what a check of this shape cannot do: the first attempt tried to prove the conflict case with `xdg.portal.config`, which merges into a list rather than conflicting, so the check passed on genuinely broken input. Pick an option that is single-valued when testing a collision.

## Booted-VM tests

Five of them, in `modules/core/tests.nix`, deliberately **not** flake checks — `nix flake check` gates CI's `build` job and `heal` only fires when `build` fails, so anything heavy or flaky in `checks` turns a caddy-hash drift into a skipped build and a dead self-heal.

| test | what it proves |
|---|---|
| `test-greeter` | the greeter draws a usable prompt, and keeps drawing it |
| `test-session` | greetd autologin → Sway yields a working session (zuko's path) |
| `test-session-gdm` | the same, started from the `.desktop` entry by GDM (katara's path) |
| `test-session-ironbar` | the other bar comes up, on the target it follows rather than an anchor |
| `test-session-niri` | the other compositor's session plumbing — **and nothing on screen**, see below |

The four session tests are one `mkSessionTest` function, over the greeter, the bar and the session. The greeters start a session by genuinely different means: greetd runs `den.desktop.sessionCommands` as a command line, GDM execs the generated desktop entry. That is where the unquoted `--cmd` bug lived, and it is the only part of the uwsm switch that behaves differently per host — so both are worth booting. The third varies the bar instead of the greeter, on the cheaper of the two: ironbar follows `den-session.target` rather than an anchor and its producers race the daemon at login, and neither shows up in an evaluation. The fourth varies the compositor, because everything uwsm does is generic in principle and had only ever been exercised by one.

All four session tests assert what no evaluation can see: `wayland-session@<session>.target` is *reached* (which under uwsm means `uwsm finalize` really ran, since the unit is `Type=notify`), `den-session.target` follows it, the bar (waybar-`<session>`, or ironbar plus its producer) with kanshi and swayidle are active **and have not restarted** ten seconds later, and `XDG_CURRENT_DESKTOP=<session>` in the session's systemd environment — that last one decides whether `<session>-mimeapps.list` is ever read. For sway it comes from nixpkgs' *wrapper*, so it holds on the greetd `--cmd` path as well as GDM's desktop-entry path; for niri, which has no wrapper, uwsm exports it from the compositor id.

All five preselect the uwsm session, mirroring the hosts. That is deliberate: its command is multi-word, so the greeter only renders if `login/greetd.nix` quotes it into a single `--cmd` argument.

The `NRestarts` assertion is the load-bearing one. `is-active` alone is satisfied by a service that starts, dies and is restarted, which is exactly how a bar can be "active" with nothing on screen — and it is what caught kanshi crash-looping on an empty config (`features/desktop/kanshi.nix` now enables it only for a user who has `monitors`). Its first screenshot was a black screen with a mouse cursor and every unit reported active.

**`test-session-niri` proves strictly less than the sway runs, and this is the one thing to know before trusting it.** niri is smithay, and smithay **refuses software EGL outright** — `ensure!(!egl_device.is_software(), "software EGL renderers are skipped")` in `src/backend/tty.rs`, with no config key and no environment variable to override it (upstream's reason: llvmpipe segfaults importing dmabufs from other renderers). A nix build sandbox has no real render node, so niri comes up with **zero outputs**: the journal reads `failed to initialize renderer, falling back to primary gpu` then `no allocator available for device`, `lxqt-policykit-agent` logs `There are no outputs - creating placeholder screen`, and the screenshot is uwsm's console output rather than a desktop. Every unit is nevertheless active with no restarts, so the test passes — read it as a test of the *session plumbing* only. That plumbing is real and was the actual integration risk: the anchor is reached, so `uwsm finalize` ran from niri's own `spawn-at-startup`; `NIRI_SOCKET` and `DISPLAY` both appear in the log as exported (the latter being xwayland-satellite); and the rewritten session entry is what greetd used. **That a bar appears has to be checked by hand on real hardware**, where the GPU is not software and the rejection never fires. sway does not have this problem because wlroots takes a software renderer by name (`WLR_RENDERER = "pixman"`), which is why its screenshot shows a real waybar over a real wallpaper — compare the two screenshots if you ever doubt which is which.

Do not try to fix this with `-device virtio-gpu-gl-pci`: virgl needs host GPU access, which a nix build sandbox does not have. nixpkgs' own `nixos/tests/cosmic` is smithay too and simply never screenshots a compositor-rendered frame.

Two environment notes for anyone extending it: `-vga none -device virtio-gpu-pci` is needed by both sessions (`-vga std` exposes no DRM node at all, lifted from nixpkgs' own `nixos/tests/sway.nix`) while `WLR_RENDERER` is set only for sway, since it means nothing to a non-wlroots compositor; and gammastep is excluded from the assertions because geoclue has no location to give in a VM, so it crash-loops there regardless of configuration.

Writing `media-plumbing` also caught a bug in the check rather than the code — asserting list equality on `RequiresMountsFor` failed for four services because upstream contributes its own entries. Expect that: a new check's first failure is as likely to be its own fault as the code's.
