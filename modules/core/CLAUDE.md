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
| `module-keys` | every module declares `key = "den:<class>.<name>"`, and no two share one |
| `ironbar-config` | the generated ironbar config parses, per ironbar itself |
| `ghostty-config` | the generated ghostty config parses, per ghostty itself |
| `media-plumbing` | `den.media.services` really generates what it claims, for every entry |

All but the two `*-config` checks are **evaluation-only**; those run a validator over generated files and build nothing else.

**Host builds deliberately do *not* live here**, even though `nix flake check` is the obvious place for them: `.github/workflows/_build.yml` already builds every host in a matrix with per-host error logs, and `ci.yml` gates `build` on `check` while `heal` fires on `build` *failing*. A host build inside `checks` moves a caddy-hash drift from `build` (fails → heal runs) to `check` (fails → build skipped → heal never runs), silently disabling the caddy self-heal. Build a host by hand instead:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

The desktop checks carry the most weight, because `den.desktop`'s assertions are all that stand between a typo and a machine with no way to log in — and no host exercises the two-environment path, let alone one user carrying three, so it would rot unnoticed. They read `config.assertions` and a handful of option values rather than forcing `system.build.toplevel`, which is what keeps that many NixOS evaluations affordable.

`session-anchors` covers the failure mode `desktop-matrix` structurally cannot see. Home Manager config lands in a *home*, not in a session — so every evaluated option value can be correct while a unit is bound to `graphical-session.target`, which every desktop starts. It probes katara through **shari**, who only ever logs into GNOME and is therefore where an escaping companion shows up. It also forces her `home.activationPackage.drvPath`, so an option two desktops define differently fails here rather than at switch time; that full Home Manager evaluation is the bulk of the check's cost, while the desktop cases stay cheap.

`terminal-choice` exists because the terminal is the one thing a session names that is *not* the option's value: `den.desktop.terminal = "foot"` has to reach `Mod+Return` as **footclient**. A package list would look right in both cases, so the check reads what a session actually states and asserts the losing terminal is not installed.

`unit-shape` exists because comparing evaluated option *values* is blind to *added* systemd directives — which is how `services.greetd.useTextGreeter` once shipped and left the greeter drawing its clock onto a console systemd had reset underneath it. It pins the set of directive *names* per section, never their values: store paths and package versions live in values, and pinning those would make the check fire on every `nix flake update`.

`media-plumbing` asserts properties over every `den.media.services` entry rather than a golden snapshot, so a service added later is covered for free. Note `requiresMounts` is checked by *containment*, not equality — the upstream service modules add their own state directories to `RequiresMountsFor`.

`module-keys` reads a `key` out of every `flake.modules.{nixos,homeManager}.*`, which needs two tricks. Most module bodies are **functions**, so it applies them — with each argument stubbed as a `throw`, which is safe only because a key is a literal and laziness never forces an argument to read one. And it **stops descending at the first node that declares a key**, because what a module imports below that are *other* named modules, checked under their own names; without that rule a keyless module would report its imports' keys and pass. What it cannot see is whether `key` is the *first* attribute, since Nix attrsets are unordered — that half stays a convention.

**When adding or changing a check, prove it bites.** Break the thing on purpose, confirm the check fails with a message that names the problem, then revert. A check that has never failed is not known to work. Two things that shaped how these are written:

- **Test a collision with a single-valued option.** The first `session-anchors` attempt tried to prove the conflict case with `xdg.portal.config`, which merges into a list rather than conflicting — so the check passed on genuinely broken input.
- **A new check's first failure is as likely to be its own fault as the code's.** `media-plumbing` asserted list equality on `RequiresMountsFor` and failed on four services because upstream contributes its own entries.

## Booted-VM tests

Four of them, in `modules/core/tests.nix`, deliberately **not** flake checks — `nix flake check` gates CI's `build` job and `heal` only fires when `build` fails, so anything heavy or flaky in `checks` turns a caddy-hash drift into a skipped build and a dead self-heal.

| test | what it proves |
|---|---|
| `test-greeter` | the greeter draws a usable prompt, and keeps drawing it |
| `test-session` | greetd autologin → Sway yields a working session (zuko's path) |
| `test-session-gdm` | the same, started from the `.desktop` entry by GDM (katara's path) |
| `test-session-ironbar` | the other bar comes up, on the target it follows rather than an anchor |

The three session tests are one `mkSessionTest` function, over the greeter and the bar. The greeters start a session by genuinely different means: greetd runs `den.desktop.sessionCommands` as a command line, GDM execs the generated desktop entry. That is where the unquoted `--cmd` bug lived, and it is the only part of the uwsm switch that behaves differently per host — so both are worth booting. The third varies the bar instead of the greeter, on the cheaper of the two: ironbar follows `den-session.target` rather than an anchor and its producers race the daemon at login, and neither shows up in an evaluation.

All three session tests assert what no evaluation can see: `wayland-session@<session>.target` is *reached* (which under uwsm means `uwsm finalize` really ran, since the unit is `Type=notify`), `den-session.target` follows it, the bar with kanshi and swayidle are active **and have not restarted** ten seconds later, and `XDG_CURRENT_DESKTOP=<session>` in the session's systemd environment — that last one decides whether `<session>-mimeapps.list` is ever read.

All four preselect the uwsm session, mirroring the hosts. That is deliberate: its command is multi-word, so the greeter only renders if `login/greetd.nix` quotes it into a single `--cmd` argument.

The `NRestarts` assertion is the load-bearing one. `is-active` alone is satisfied by a service that starts, dies and is restarted, which is exactly how a bar can be "active" with nothing on screen — and it is what caught kanshi crash-looping on an empty config (`features/desktop/kanshi.nix` now enables it only for a user who has `monitors`).

Two environment notes for anyone extending it: `-vga none -device virtio-gpu-pci` is needed (`-vga std` exposes no DRM node at all, lifted from nixpkgs' own `nixos/tests/sway.nix`) while `WLR_RENDERER` is set for sway; and gammastep is excluded from the assertions because geoclue has no location to give in a VM, so it crash-loops there regardless of configuration.
