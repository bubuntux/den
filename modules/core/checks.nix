{ self, inputs, ... }:
{
  # Evaluation-only checks; host builds deliberately live in CI instead, so a
  # build failure still triggers the caddy self-heal. See CLAUDE.md, "Checks".
  perSystem =
    {
      system,
      lib,
      pkgs,
      ...
    }:
    let
      compatibleHosts = lib.filterAttrs (
        _: cfg: cfg.config.nixpkgs.system == system
      ) self.nixosConfigurations;

      # --- desktop probes ----------------------------------------------------

      # Minimum needed to evaluate a NixOS config; none of it is under test.
      stub = {
        boot.loader.grub.devices = [ "nodev" ];
        fileSystems."/" = {
          device = "/dev/vda1";
          fsType = "ext4";
        };
        networking.hostName = "probe";
        system.stateVersion = "25.11";
        nixpkgs.hostPlatform = system;
        users.users.bbtux.isNormalUser = true;
        users.users.shari.isNormalUser = true;
      };

      probe =
        modules:
        (inputs.nixpkgs.lib.nixosSystem {
          specialArgs = { inherit self inputs; };
          modules = [ stub ] ++ modules;
        }).config;

      # Only `config.assertions` is forced, never system.build.toplevel: the
      # point is to check the decision logic, not to build ten desktops.
      failedAssertions = c: map (a: a.message) (lib.filter (a: !a.assertion) c.assertions);

      # --- valid combinations ------------------------------------------------

      facts = c: {
        sessions = lib.sort (a: b: a < b) c.services.displayManager.sessionData.sessionNames;
        greetd = c.services.greetd.enable;
        gdm = c.services.displayManager.gdm.enable;
        lightdm = c.services.xserver.displayManager.lightdm.enable;
        xserver = c.services.xserver.enable;
        sway = c.programs.sway.enable;
        niri = c.programs.niri.enable;
        gnome = c.services.desktopManager.gnome.enable;
        autoLoginUser = c.services.displayManager.autoLogin.user;
        # Defaults to just the bar that starts: the second one is ~210 MiB a
        # host does not pay for unless it asked to compare them.
        barsInstalled = c.den.desktop.barsInstalled;
        hmUsers = lib.sort (a: b: a < b) (lib.attrNames c.home-manager.users);
        greeterCmd =
          if c.services.greetd.enable then c.services.greetd.settings.default_session.command else "";
        # Pinned off: added by accident during the DE/DM split, never part of
        # the working config. See login/greetd.nix.
        useTextGreeter = c.services.greetd.useTextGreeter;
      };

      cases = [
        {
          name = "sway on greetd (what zuko and katara run)";
          modules = [
            {
              den.desktop = {
                environments = [ "sway" ];
                loginManager = "greetd";
              };
              services.displayManager.defaultSession = "sway";
            }
            self.modules.nixos.bundle-desktop
          ];
          expect = {
            sessions = [
              "sway"
            ];
            greetd = true;
            gdm = false;
            lightdm = false;
            xserver = false;
            sway = true;
            gnome = false;
            # Empty on purpose: config reaches users through sharedModules, so a
            # probe with no user module has no homes. The profile cases below do.
            hmUsers = [ ];
            useTextGreeter = false;
            barsInstalled = [ "waybar" ];
          };
          # --cmd takes a single argument, so a multi-word session command has
          # to arrive quoted or tuigreet gets stray arguments and draws no
          # prompt. The opening quote before a store path pins both that and the
          # fact that the command runs uwsm.
          cmdContains = "--cmd '/nix/store";
        }
        {
          name = "sway + gnome on greetd";
          modules = [
            {
              den.desktop = {
                environments = [
                  "sway"
                  "gnome"
                ];
                loginManager = "greetd";
              };
              services.displayManager.defaultSession = "sway";
            }
            self.modules.nixos.bundle-desktop
          ];
          expect = {
            sessions = [
              "gnome"
              "sway"
            ];
            greetd = true;
            gdm = false;
            lightdm = false;
            sway = true;
            gnome = true;
            useTextGreeter = false;
          };
          # Per-user session memory: the only thing that is per user now.
          cmdContains = "--remember-user-session";
        }
        {
          name = "sway + gnome on gdm";
          modules = [
            {
              den.desktop = {
                environments = [
                  "sway"
                  "gnome"
                ];
                loginManager = "gdm";
              };
              services.displayManager.defaultSession = "gnome";
            }
            self.modules.nixos.bundle-desktop
          ];
          expect = {
            sessions = [
              "gnome"
              "sway"
            ];
            greetd = false;
            gdm = true;
            lightdm = false;
            sway = true;
            gnome = true;
          };
        }
        {
          # The second bare compositor, and the one that proves nothing about
          # uwsm was sway-shaped. The trailing quote in cmdContains is the whole
          # point: it pins both that sessionCommands was keyed "niri" (rewriting
          # the shipped entry keeps the plain id) and that the multi-word command
          # reached tuigreet as one --cmd argument.
          name = "niri on greetd";
          modules = [
            {
              den.desktop = {
                environments = [ "niri" ];
                loginManager = "greetd";
              };
              services.displayManager.defaultSession = "niri";
            }
            self.modules.nixos.bundle-desktop
          ];
          expect = {
            sessions = [ "niri" ];
            greetd = true;
            gdm = false;
            sway = false;
            niri = true;
            gnome = false;
            useTextGreeter = false;
          };
          cmdContains = "-- /run/current-system/sw/bin/niri'";
        }
        {
          # katara's shape: three sessions in one greeter, two of them bare
          # compositors sharing every companion.
          name = "sway + niri + gnome on gdm (katara)";
          modules = [
            {
              den.desktop = {
                environments = [
                  "sway"
                  "niri"
                  "gnome"
                ];
                loginManager = "gdm";
              };
            }
            self.modules.nixos.bundle-desktop
          ];
          expect = {
            sessions = [
              "gnome"
              "niri"
              "sway"
            ];
            greetd = false;
            gdm = true;
            lightdm = false;
            sway = true;
            niri = true;
            gnome = true;
          };
        }
        {
          name = "sway on lightdm (X server forced on for a Wayland-only session)";
          modules = [
            {
              den.desktop = {
                environments = [ "sway" ];
                loginManager = "lightdm";
              };
              services.displayManager.defaultSession = "sway";
            }
            self.modules.nixos.bundle-desktop
          ];
          expect = {
            sessions = [
              "sway"
            ];
            greetd = false;
            gdm = false;
            lightdm = true;
            xserver = true;
          };
        }
        {
          # A family-only machine. The greeter and autologin are supplied here
          # rather than by the profile, which is how a real host does it: those
          # are single-valued, so a profile that named them could not be
          # combined with another role.
          name = "profile-family alone: gnome on gdm with autologin";
          modules = [
            self.modules.nixos.bundle-host
            self.modules.nixos.profile-family
            {
              den.desktop.loginManager = "gdm";
              services.displayManager.defaultSession = "gnome";
              services.displayManager.autoLogin = {
                enable = true;
                user = "shari";
              };
            }
          ];
          expect = {
            sessions = [
              "gnome"
              "sway"
            ];
            greetd = false;
            gdm = true;
            gnome = true;
            autoLoginUser = "shari";
            hmUsers = [
              "bbtux"
              "shari"
            ];
          };
        }
        {
          # katara's shape: two roles on one machine, one greeter. Proves the
          # additive settings merge instead of colliding.
          name = "profile-family + profile-workstation on one host (katara)";
          modules = [
            self.modules.nixos.bundle-host
            self.modules.nixos.profile-family
            self.modules.nixos.profile-workstation
            {
              den.desktop.loginManager = "gdm";
              services.displayManager.defaultSession = "gnome";
            }
          ];
          expect = {
            sessions = [
              "gnome"
              "sway"
            ];
            greetd = false;
            gdm = true;
            sway = true;
            gnome = true;
            # A shared machine must not log anyone in unattended. This caught a
            # real regression: user-shari used to set autoLogin.user, and
            # autoLogin.enable defaults to `user != null`, so importing that user
            # silently gave the whole host autologin.
            autoLoginUser = null;
            hmUsers = [
              "bbtux"
              "shari"
            ];
          };
        }
      ];

      checkCase =
        case:
        let
          c = probe case.modules;
          got = facts c;
          broke = failedAssertions c;
          wrong = lib.filter (k: got.${k} != case.expect.${k}) (lib.attrNames case.expect);
          cmdMissing = case ? cmdContains && !lib.hasInfix case.cmdContains got.greeterCmd;
        in
        lib.optional (
          broke != [ ]
        ) "${case.name}: assertion fired unexpectedly: ${lib.concatStringsSep "; " broke}"
        ++ map (
          k:
          "${case.name}: ${k} = ${lib.generators.toPretty { } got.${k}}, expected ${
            lib.generators.toPretty { } case.expect.${k}
          }"
        ) wrong
        ++ lib.optional cmdMissing "${case.name}: greeter command is missing ${case.cmdContains}: ${got.greeterCmd}";

      # --- invalid combinations ---------------------------------------------

      rejects = [
        {
          name = "environments installed but nothing can start a session";
          modules = [
            {
              den.desktop = {
                environments = [ "sway" ];
                loginManager = "none";
              };
            }
            self.modules.nixos.bundle-desktop
          ];
        }
        {
          name = "autologin with two environments and no defaultSession";
          modules = [
            {
              den.desktop = {
                environments = [
                  "sway"
                  "gnome"
                ];
                loginManager = "gdm";
              };
              services.displayManager.autoLogin = {
                enable = true;
                user = "bbtux";
              };
            }
            self.modules.nixos.bundle-desktop
          ];
        }
        {
          name = "greetd autologin into a session that publishes no command";
          modules = [
            {
              den.desktop = {
                environments = [ "gnome" ];
                loginManager = "greetd";
              };
              services.displayManager.autoLogin = {
                enable = true;
                user = "bbtux";
              };
            }
            self.modules.nixos.bundle-desktop
          ];
        }
        {
          name = "an environment that does not exist";
          modules = [
            { den.desktop.environments = [ "kde" ]; }
            self.modules.nixos.bundle-desktop
          ];
        }
      ];

      # A reject passes if evaluation throws (a type error, e.g. an unknown
      # environment) or if at least one assertion reports false.
      checkReject =
        case:
        let
          attempt = builtins.tryEval (failedAssertions (probe case.modules));
        in
        lib.optional (
          attempt.success && attempt.value == [ ]
        ) "${case.name}: was accepted, expected rejection";

      failures = lib.concatMap checkCase cases ++ lib.concatMap checkReject rejects;

      # --- session anchors ---------------------------------------------------
      #
      # Every evaluated option value can be correct while a unit is bound to
      # graphical-session.target, which every desktop starts. Costs a full Home
      # Manager evaluation. See CLAUDE.md, "Checks".
      anchorFailures =
        let
          c = probe [
            self.modules.nixos.bundle-host
            self.modules.nixos.profile-family
            self.modules.nixos.profile-workstation
            {
              den.desktop.loginManager = "gdm";
              # Pinned, not defaulted: this probe is about the per-session
              # bars, which only waybar builds.
              den.desktop.bar = "waybar";
              # katara's third session, added here rather than by a profile for
              # the same reason the host does it. Two bare compositors in one
              # home is what makes the per-session scoping load-bearing rather
              # than theoretical.
              den.desktop.environments = [ "niri" ];
              services.displayManager.defaultSession = "gnome";
              # A display layout, pushed schema-and-values the way every host
              # does it. kanshi is only enabled for a user who has monitors, so
              # without this the probe would be a machine nobody runs, and the
              # kanshi assertion below would report it missing rather than
              # unanchored.
              home-manager.sharedModules = [
                {
                  imports = [ self.modules.homeManager.monitors ];
                  monitors = [
                    {
                      name = "eDP-1";
                      primary = true;
                      width = 2560;
                      height = 1600;
                    }
                  ];
                }
              ];
            }
          ];
          # shari, not bbtux: she is the one who only ever logs into GNOME, so
          # she is where a companion escaping its session is visible. She carries
          # Sway's config all the same -- every user on the host does.
          hm = c.home-manager.users.shari;
          units = hm.systemd.user.services;
          wantedBy = n: units.${n}.Install.WantedBy or [ ];

          # The companions session/wayland.nix supplies. Named individually so
          # this fails when one of them stops being bound rather than when it
          # stops existing.
          companions = [
            "gammastep"
            "geoclue-agent"
            "idle-inhibit-init"
            "kanshi"
            "network-manager-applet"
            "swayidle"
          ];
          sessionTarget = "den-session.target";
          anchors = lib.attrValues hm.den.session.anchors;

          # drvPath, not a build: forces the whole config, so an option two
          # desktops define differently fails here rather than at switch time.
          evaluated = hm.home.activationPackage.drvPath;

          # thunar is right in a bare session and wrong in GNOME, and both are in
          # this home: every bare session gets it, the shared list must not.
          mimeFor = desktop: hm.xdg.configFile."${desktop}-mimeapps.list".text or null;
          sharedDefault = hm.xdg.mimeApps.defaultApplications."inode/directory" or null;
        in
        builtins.seq evaluated (
          # Nothing the user owns may follow the seat instead of the session.
          # gnome-keyring is the one exception by design and is bound to
          # graphical-session-pre.target, so it does not match.
          map (n: "${n}.service is WantedBy graphical-session.target, which GNOME also starts") (
            lib.filter (n: lib.elem "graphical-session.target" (wantedBy n)) (lib.attrNames units)
          )
          ++ lib.concatMap (
            n:
            lib.optional (!(units ? ${n})) "${n}.service is missing from a user who has a bare session"
            ++ lib.optional (
              units ? ${n} && !(lib.elem sessionTarget (wantedBy n))
            ) "${n}.service is not WantedBy ${sessionTarget} (got ${lib.generators.toPretty { } (wantedBy n)})"
          ) companions
          # The shared target is what turns a list of anchors into the single unit
          # those companions name, so it has to be started by every one of them
          # -- miss one and that session comes up with no companions at all.
          ++
            lib.optional ((hm.systemd.user.targets.den-session.Install.WantedBy or [ ]) != anchors)
              "${sessionTarget} is not started by every anchor ${lib.generators.toPretty { } anchors} (got ${
                lib.generators.toPretty { } (hm.systemd.user.targets.den-session.Install.WantedBy or [ ])
              })"
          # ... and the bars are the counter-case: each is built from one
          # compositor's modules, so it follows that session's anchor alone and
          # not the union of the user's sessions.
          ++ lib.optional (
            hm.den.session.bar == { }
          ) "no session contributes a bar, so the assertions below cannot fail"
          ++ lib.concatMap (
            id:
            let
              unit = "waybar-${id}";
              anchor = hm.den.session.anchors.${id};
            in
            lib.optional (!(units ? ${unit})) "${unit}.service is missing from a user who has the ${id} session"
            ++
              lib.optional (units ? ${unit} && wantedBy unit != [ anchor ])
                "${unit}.service should be WantedBy ${anchor} only (got ${
                  lib.generators.toPretty { } (wantedBy unit)
                })"
          ) (lib.attrNames hm.den.session.bar)
          # The other unit belonging to one session rather than the home: niri
          # draws no wallpaper of its own, where sway's is a compositor setting.
          ++ (
            let
              anchor = hm.den.session.anchors.niri;
            in
            lib.optional (
              !(units ? niri-wallpaper)
            ) "niri-wallpaper.service is missing from a user who has the niri session"
            ++
              lib.optional (units ? niri-wallpaper && wantedBy "niri-wallpaper" != [ anchor ])
                "niri-wallpaper.service should be WantedBy ${anchor} only (got ${
                  lib.generators.toPretty { } (wantedBy "niri-wallpaper")
                })"
          )
          ++ lib.concatMap (
            desktop:
            lib.optional (
              mimeFor desktop == null || !lib.hasInfix "thunar.desktop" (mimeFor desktop)
            ) "${desktop}-mimeapps.list does not point inode/directory at thunar"
          ) (lib.attrNames hm.den.session.anchors)
          ++
            lib.optional (sharedDefault != null)
              "the shared mimeapps.list sets inode/directory (${
                lib.generators.toPretty { } sharedDefault
              }), which would follow the user into GNOME"
        );

      # --- the other bar -----------------------------------------------------
      #
      # ironbar is one bar for every session, so it follows the shared target
      # rather than an anchor -- the opposite of the rule above, and the reason
      # it needs its own probe. Cheap on purpose: no activation package is
      # forced, only the units are read.
      ironbarFailures =
        let
          c = probe [
            self.modules.nixos.bundle-host
            self.modules.nixos.profile-workstation
            {
              den.desktop.loginManager = "greetd";
              den.desktop.bar = "ironbar";
              # Both installed, which is the interesting case: the units of the
              # bar that did not win must exist and be wanted by nothing.
              den.desktop.barsInstalled = [
                "waybar"
                "ironbar"
              ];
              services.displayManager.defaultSession = "sway";
            }
          ];
          units = c.home-manager.users.bbtux.systemd.user.services;
          wantedBy = n: units.${n}.Install.WantedBy or [ ];
          # The bar follows the session; its producers follow the bar, so
          # starting one unit by hand brings up the whole set.
          expected = {
            ironbar = [ "den-session.target" ];
            ironbar-vars = [ "ironbar.service" ];
            ironbar-weather = [ "ironbar.service" ];
          };
        in
        lib.concatMap (
          n:
          lib.optional (!(units ? ${n})) "${n}.service is missing when den.desktop.bar = \"ironbar\""
          ++
            lib.optional (units ? ${n} && wantedBy n != expected.${n})
              "${n}.service should be WantedBy ${lib.head expected.${n}} only (got ${
                lib.generators.toPretty { } (wantedBy n)
              })"
        ) (lib.attrNames expected)
        # The loser is installed and inert. Present, so `systemctl --user start`
        # reaches it; wanted by nothing, so the session never brings up two bars.
        ++ lib.optional (
          !(lib.any (lib.hasPrefix "waybar") (lib.attrNames units))
        ) "no waybar unit exists even though barsInstalled asks for it"
        ++ map (
          n:
          "${n}.service is WantedBy ${lib.generators.toPretty { } (wantedBy n)} but ironbar is the active bar"
        ) (lib.filter (n: lib.hasPrefix "waybar" n && wantedBy n != [ ]) (lib.attrNames units));

      # --- the terminal ------------------------------------------------------
      #
      # den.desktop.terminal has to install one terminal and uninstall the
      # other, and the command sway spawns has to be the one that module states
      # -- footclient, not foot, which no evaluated package list would show.
      terminalFailures =
        let
          # foot reaches its server through footclient; ghostty is spawned
          # directly. Keyed by module name, which is what the option takes.
          expected = {
            foot = "footclient";
            ghostty = "ghostty";
          };

          # One probe per terminal, bound once: each is a whole NixOS plus Home
          # Manager evaluation, and footServer below reads the same home.
          homes = lib.mapAttrs (
            name: _:
            (probe [
              self.modules.nixos.bundle-host
              self.modules.nixos.profile-workstation
              {
                den.desktop.loginManager = "greetd";
                den.desktop.terminal = name;
                # Both bare sessions, because each states the spawn command in
                # its own syntax and only one of them has a Home Manager module
                # to be wrong about it.
                den.desktop.environments = [ "niri" ];
                services.displayManager.defaultSession = "sway";
              }
            ]).home-manager.users.bbtux
          ) expected;

          check =
            name:
            let
              hm = homes.${name};
              other = if name == "foot" then "ghostty" else "foot";
              enabled = t: hm.programs.${t}.enable or false;
              spawned = hm.wayland.windowManager.sway.config.terminal;
              # A hand-written KDL string, so the command is only ever as right
              # as this infix -- there is no option to read it back out of.
              niriConfig = hm.xdg.configFile."niri/config.kdl".text;
            in
            lib.optional (
              !enabled name
            ) "programs.${name}.enable is false when den.desktop.terminal = \"${name}\""
            ++ lib.optional (enabled other) "programs.${other} is installed even though den.desktop.terminal = \"${name}\""
            ++ lib.optional (
              spawned != expected.${name}
            ) "sway spawns ${spawned} when den.desktop.terminal = \"${name}\", expected ${expected.${name}}"
            ++ lib.optional (
              !lib.hasInfix "-terminal ${expected.${name}} " hm.wayland.windowManager.sway.config.menu
            ) "the rofi launcher does not pass -terminal ${expected.${name}}"
            ++ lib.optional (
              !lib.hasInfix ''spawn "${expected.${name}}";'' niriConfig
            ) "the niri config does not spawn ${expected.${name}} when den.desktop.terminal = \"${name}\""
            ++ lib.optional (lib.hasInfix ''spawn "${expected.${other}}";'' niriConfig) "the niri config still spawns ${expected.${other}} when den.desktop.terminal = \"${name}\"";

          # The server is a companion like any other: it must follow the shared
          # session target, not graphical-session.target, or a GNOME login in
          # the same home starts a foot server it has no terminal for.
          footServer =
            let
              unit = homes.foot.systemd.user.services.foot or null;
            in
            lib.optional (unit == null) "foot.service is missing when den.desktop.terminal = \"foot\""
            ++
              lib.optional (unit != null && (unit.Install.WantedBy or [ ]) != [ "den-session.target" ])
                "foot.service should be WantedBy den-session.target only (got ${
                  lib.generators.toPretty { } (unit.Install.WantedBy or [ ])
                })";
        in
        lib.concatMap check (lib.attrNames expected) ++ footServer;

      # --- unit shape --------------------------------------------------------
      #
      # Directive *names* per section, never their values: values carry store
      # paths and would churn on every flake update. See CLAUDE.md, "Checks".
      directivesOf =
        text:
        let
          # Unit text carries string context from the store paths inside it, and
          # that context propagates into anything derived from it -- including
          # attribute names, which Nix rejects. Only names are kept here, so
          # dropping the context is safe.
          lines = map builtins.unsafeDiscardStringContext (
            lib.filter (l: l != "") (lib.splitString "\n" text)
          );
          step =
            acc: line:
            if lib.hasPrefix "[" line then
              acc // { section = lib.removeSuffix "]" (lib.removePrefix "[" line); }
            else
              let
                # Hyphens matter: systemd's X- extension directives use them.
                m = builtins.match "([A-Za-z0-9_-]+)=.*" line;
              in
              if m == null then
                acc
              else
                acc
                // {
                  found = acc.found // {
                    ${acc.section} = lib.unique ((acc.found.${acc.section} or [ ]) ++ [ (builtins.head m) ]);
                  };
                };
          result = lib.foldl' step {
            section = "?";
            found = { };
          } lines;
        in
        lib.mapAttrs (_: lib.sort (a: b: a < b)) result.found;

      unitShapes = [
        {
          name = "greetd.service on a sway/greetd host";
          modules = [
            {
              den.desktop = {
                environments = [ "sway" ];
                loginManager = "greetd";
              };
              services.displayManager.defaultSession = "sway";
            }
            self.modules.nixos.bundle-desktop
          ];
          unit = c: c.systemd.units."greetd.service".text;
          # Baseline taken from the pre-refactor unit. The TTY family
          # (TTYPath, TTYReset, TTYVHangup, TTYVTDisallocate, StandardInput,
          # StandardOutput, StandardError) is absent on purpose -- that is the
          # useTextGreeter regression this check exists to catch.
          expect = {
            Unit = [
              "After"
              "Conflicts"
              "Wants"
            ];
            Service = [
              "Environment"
              "ExecStart"
              "IgnoreSIGPIPE"
              "KeyringMode"
              "Restart"
              "SendSIGHUP"
              "TimeoutStopSec"
              "Type"
              "X-RestartIfChanged"
            ];
            Install = [ "WantedBy" ];
          };
        }
      ];

      checkShape =
        case:
        let
          got = directivesOf (case.unit (probe case.modules));
          sections = lib.unique (lib.attrNames got ++ lib.attrNames case.expect);
        in
        lib.concatMap (
          s:
          let
            g = got.${s} or [ ];
            e = case.expect.${s} or [ ];
            added = lib.subtractLists e g;
            removed = lib.subtractLists g e;
          in
          lib.optional (added != [ ]) "${case.name}: [${s}] gained ${toString added}"
          ++ lib.optional (removed != [ ]) "${case.name}: [${s}] lost ${toString removed}"
        ) sections;

      # --- media registry ----------------------------------------------------
      #
      # Properties over every den.media.services entry rather than a golden
      # snapshot, so a service added later is covered automatically. This is the
      # permanent version of the throwaway diff that caught immich's
      # RequiresMountsFor changing shape.
      mediaFailures =
        let
          c = self.nixosConfigurations.appa.config;
          svc = c.den.media.services;
        in
        lib.concatMap (
          name:
          let
            s = svc.${name};
            unit = c.systemd.services.${s.unit} or { };
            sc = unit.serviceConfig or { };
            route = c.services.reverse-proxy.routes.${name} or null;
            ns = if s.namespace == null then null else c.vpnNamespaces.${s.namespace};
            addr = if s.inNamespace then ns.namespaceAddress else ns.bridgeAddress;
            forwarded = map (f: f.guest.port) c.virtualisation.vmVariant.virtualisation.forwardPorts;
          in
          lib.optional (
            s.mediaGroup && s.user != null && !lib.elem "media" c.users.users.${s.user}.extraGroups
          ) "${name}: mediaGroup is set but ${s.user} is not in the media group"
          ++ lib.optional (
            s.umask != null && (sc.UMask or null) != s.umask
          ) "${name}: umask ${s.umask} did not reach ${s.unit} (got ${toString (sc.UMask or "unset")})"
          # Containment, not equality: the upstream service modules add their own
          # state directories to RequiresMountsFor (jellyfin contributes three),
          # so all we can assert is that everything we asked for is in there.
          ++ map (m: "${name}: requiresMounts ${m} did not reach ${s.unit}") (
            lib.subtractLists (unit.unitConfig.RequiresMountsFor or [ ]) s.requiresMounts
          )
          ++ lib.optional (
            s.resources != null
            && (
              (sc.MemoryHigh or null) != s.resources.memoryHigh
              || (sc.MemoryMax or null) != s.resources.memoryMax
              || (sc.CPUWeight or null) != s.resources.cpuWeight
              || (sc.IOWeight or null) != s.resources.ioWeight
              || (sc.CPUQuota or null) != s.resources.cpuQuota
            )
          ) "${name}: resource caps did not reach ${s.unit}"
          ++ lib.optional (
            s.proxy && (route == null || route.port != s.port)
          ) "${name}: proxy route missing or has the wrong port"
          ++ lib.optional (
            s.proxy && s.inNamespace && route.upstreamAddr != ns.namespaceAddress
          ) "${name}: in-namespace service is not proxied to the namespace address"
          ++ lib.optional (
            s.namespace != null && !lib.elem "${name}.wg" (c.networking.hosts.${addr} or [ ])
          ) "${name}: ${name}.wg alias missing at ${addr}"
          ++ lib.optional (
            !lib.elem s.port forwarded
          ) "${name}: port ${toString s.port} is not forwarded in the VM build"
        ) (lib.attrNames svc);

      # --- module keys -------------------------------------------------------

      # Reading a key means applying the module, since most are functions. Its
      # arguments are stubbed with throws, which is safe only because a key is a
      # literal and laziness never forces them to read one.
      moduleKeys =
        m:
        if lib.isFunction m then
          moduleKeys (
            m (
              lib.mapAttrs (n: _: throw "module argument '${n}' forced while reading key") (lib.functionArgs m)
            )
          )
        else if lib.isList m then
          lib.concatMap moduleKeys m
        else if lib.isAttrs m then
          # Stop at a node that declares one: whatever it imports are other
          # named modules, checked under their own names.
          if m ? key then
            [ m.key ]
          else if m ? imports then
            lib.concatMap moduleKeys m.imports
          else
            [ null ]
        else
          [ ];

      moduleKeyFailures =
        let
          entries =
            lib.concatMap
              (
                class:
                lib.concatMap (
                  name: map (key: { inherit class name key; }) (moduleKeys self.modules.${class}.${name})
                ) (lib.attrNames self.modules.${class})
              )
              [
                "nixos"
                "homeManager"
              ];

          shape =
            e:
            let
              want = "den:${e.class}.${e.name}";
            in
            if e.key == null then
              [ ''${e.class}.${e.name}: no key -- add `key = "${want}";` as the first attribute'' ]
            else if e.key == want || lib.hasPrefix "${want}#" e.key then
              [ ]
            else
              [ ''${e.class}.${e.name}: key is "${e.key}", want "${want}" or "${want}#<fragment>"'' ];

          collisions =
            lib.mapAttrsToList
              (
                key: es:
                ''key "${key}" is claimed by ${
                  lib.concatStringsSep " and " (map (e: "${e.class}.${e.name}") es)
                } -- all but the first are dropped silently''
              )
              (
                lib.filterAttrs (_: es: lib.length es > 1) (
                  lib.groupBy (e: e.key) (lib.filter (e: e.key != null) entries)
                )
              );
        in
        lib.concatMap shape entries ++ collisions;

      mkCheck =
        name: found:
        if found == [ ] then
          pkgs.runCommand "check-${name}-ok" { } "touch $out"
        else
          throw "${name}: ${toString (lib.length found)} failure(s)\n  ${lib.concatStringsSep "\n  " found}";
    in
    {
      checks = {
        desktop-matrix = mkCheck "desktop-matrix" (lib.concatMap checkCase cases);
        desktop-rejects = mkCheck "desktop-rejects" (lib.concatMap checkReject rejects);
        session-anchors = mkCheck "session-anchors" (anchorFailures ++ ironbarFailures);
        terminal-choice = mkCheck "terminal-choice" terminalFailures;
        unit-shape = mkCheck "unit-shape" (lib.concatMap checkShape unitShapes);
        module-keys = mkCheck "module-keys" moduleKeyFailures;

        # ironbar's config is hand-built here and read by nothing else until a
        # session starts, so let ironbar itself parse it. --validate-config
        # rejects unknown fields and bad enum variants, and needs no display.
        ironbar-config =
          let
            hm =
              (probe [
                self.modules.nixos.bundle-host
                self.modules.nixos.profile-workstation
                { den.desktop.bar = "ironbar"; }
              ]).home-manager.users.bbtux;
          in
          pkgs.runCommand "check-ironbar-config" { } ''
            # Without a home it fails on its own log directory before it ever
            # reads the config, and reports that instead of the real error.
            export HOME=$TMPDIR
            ${lib.getExe pkgs.ironbar} \
              -c ${hm.xdg.configFile."ironbar/config.json".source} -t minimal --validate-config
            touch $out
          '';

        # Same reasoning again, and strongest here: this Home Manager release has
        # no wayland.windowManager.niri, so the whole session config is one
        # hand-written KDL string with nothing between a typo and a login that
        # falls back to niri's built-in defaults. `validate` needs no display.
        niri-config =
          let
            hm =
              (probe [
                self.modules.nixos.bundle-host
                self.modules.nixos.profile-workstation
                { den.desktop.environments = [ "niri" ]; }
              ]).home-manager.users.bbtux;
          in
          pkgs.runCommand "check-niri-config" { } ''
            ${lib.getExe pkgs.niri} validate \
              -c ${hm.xdg.configFile."niri/config.kdl".source}
            touch $out
          '';

        # Same reasoning as ironbar-config: the keys are hand-written and
        # nothing reads them until a terminal starts. +validate-config rejects
        # unknown fields and bad enum variants (window-decoration takes none,
        # not false) and needs no display.
        ghostty-config =
          let
            hm =
              (probe [
                self.modules.nixos.bundle-host
                self.modules.nixos.profile-workstation
                { den.desktop.terminal = "ghostty"; }
              ]).home-manager.users.bbtux;
          in
          pkgs.runCommand "check-ghostty-config" { } ''
            export HOME=$TMPDIR
            ${lib.getExe pkgs.ghostty} +validate-config \
              --config-file=${hm.xdg.configFile."ghostty/config".source}
            touch $out
          '';
      }
      # appa is the only host with media services, and only on its own system.
      // lib.optionalAttrs (compatibleHosts ? appa) {
        media-plumbing = mkCheck "media-plumbing" mediaFailures;
      };
    };
}
