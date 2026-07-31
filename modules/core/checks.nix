{ self, inputs, ... }:
{
  # `nix flake check` used to build only treefmt and the flake-file check, so it
  # proved formatting and nothing else -- no host was built and no assertion was
  # ever exercised. These checks close that gap:
  #
  #   desktop-matrix     the DE/DM combinations produce the expected config
  #   desktop-rejects    the invalid combinations are refused
  #   session-anchors    a session's user units stay out of the user's other DEs
  #   unit-shape         no surprise systemd directives on units we configure
  #   media-plumbing     den.media.services really generates what it claims
  #
  # All of them are evaluation-only on purpose. Host builds deliberately do NOT
  # live here: .github/workflows/_build.yml already builds every host in a
  # matrix with per-host error logs, and ci.yml gates `build` on `check` while
  # `heal` triggers on `build` failing. Building hosts inside `nix flake check`
  # therefore moves a caddy-hash drift from `build` (failure -> heal runs) to
  # `check` (failure -> build skipped -> heal never runs), disabling the caddy
  # self-heal. Build a host with
  # `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.
  #
  # The desktop checks matter most. den.desktop's assertions are the only thing
  # standing between a typo and a machine that boots without a way to log in,
  # and nothing else in the repo forces them: the two-environment path is not
  # used by any host, so it would otherwise rot unnoticed.
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
        gnome = c.services.desktopManager.gnome.enable;
        autoLoginUser = c.services.displayManager.autoLogin.user;
        hmUsers = lib.sort (a: b: a < b) (lib.attrNames c.home-manager.users);
        greeterCmd =
          if c.services.greetd.enable then c.services.greetd.settings.default_session.command else "";
        # Pinned because it was not in the original config and was added by
        # accident during the DE/DM split, not because it is proven harmful --
        # a VM test with and without it renders identically. It hands systemd
        # TTYReset/TTYVHangup/TTYVTDisallocate on /dev/tty1, which greetd
        # already owns via `[terminal] vt = 1`, so it stays off until something
        # demonstrates it is needed. See the comment in login/greetd.nix.
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
            sessions = [ "sway" ];
            greetd = true;
            gdm = false;
            lightdm = false;
            xserver = false;
            sway = true;
            gnome = false;
            # Empty on purpose: desktop config now reaches users through
            # home-manager.sharedModules, so a probe without a user module has
            # no homes to show. The profile cases below are where hmUsers means
            # something.
            hmUsers = [ ];
            useTextGreeter = false;
          };
          # Preserves the pre-split behaviour: greetd ignores defaultSession
          # upstream, so den.desktop.sessionCommands has to supply --cmd.
          cmdContains = "--cmd sway";
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
          # Per-user session memory is what lets two users land in different
          # desktops from the same greeter -- the only thing that is per user
          # now, since every home carries both desktops' config.
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
            sessions = [ "sway" ];
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
      # Home Manager config lands in a *home*, not in a session, so a user's
      # units are there whichever desktop they log into. Everything a session
      # owns must therefore hang off that session's own unit
      # (den.session.anchors) rather than off graphical-session.target, which
      # every desktop starts -- GNOME included.
      #
      # This is not hypothetical. Before the anchors existed, bbtux on katara had
      # waybar, kanshi, swayidle, gammastep and geoclue-agent all WantedBy
      # graphical-session.target, and katara's defaultSession is gnome: logging
      # into GNOME drew Waybar over mutter, pointed kanshi at outputs mutter was
      # already driving and armed swaylock as the GNOME screen locker. Every
      # evaluated option value was correct, which is why desktop-matrix could not
      # see it.
      #
      # The probe is deliberately the case no host runs -- one user with both
      # desktops -- because that is where a mistake is invisible on a real
      # machine until someone switches sessions. Unlike the cases above this
      # forces a full Home Manager evaluation for that user, which is the bulk of
      # this check's cost.
      anchorFailures =
        let
          c = probe [
            self.modules.nixos.bundle-host
            self.modules.nixos.profile-family
            self.modules.nixos.profile-workstation
            {
              den.desktop.loginManager = "gdm";
              services.displayManager.defaultSession = "gnome";
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
          swayAnchor = "sway-session.target";

          # Forcing the activation package's drvPath (an instantiation, not a
          # build) evaluates the WHOLE of this user's Home Manager config. That
          # is what covers the other half of every home carrying every desktop:
          # an option two of them define differently -- the collision that used
          # to be the reason a user was assigned one desktop -- fails here rather
          # than at switch time. It has to be forced explicitly, because a module
          # definition conflicts only when something reads the option, and the
          # assertions below read units alone.
          evaluated = hm.home.activationPackage.drvPath;

          # The file-manager association is per *desktop*, not per home: thunar
          # is right in Sway and wrong in GNOME, and both are in this home. XDG
          # reads <desktop>-mimeapps.list ahead of mimeapps.list, so the pair of
          # assertions below is "Sway gets thunar" and "the shared list does not
          # hand thunar to GNOME as well".
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
            lib.optional (!(units ? ${n})) "${n}.service is missing from a user who has the Sway session"
            ++ lib.optional (
              units ? ${n} && !(lib.elem sessionTarget (wantedBy n))
            ) "${n}.service is not WantedBy ${sessionTarget} (got ${lib.generators.toPretty { } (wantedBy n)})"
          ) companions
          # The shared target is what turns a list of anchors into the single unit
          # those companions name, so it has to be started by each of them.
          ++ lib.optional (
            (hm.systemd.user.targets.den-session.Install.WantedBy or [ ]) != [ swayAnchor ]
          ) "${sessionTarget} is not started by ${swayAnchor}"
          # ... and the bar is the counter-case: its modules are sway/*, so it must
          # follow Sway alone and not the union of the user's sessions.
          ++
            lib.optional
              (!(lib.elem swayAnchor (wantedBy "waybar")) || lib.elem sessionTarget (wantedBy "waybar"))
              "waybar.service should be WantedBy ${swayAnchor} only (got ${
                lib.generators.toPretty { } (wantedBy "waybar")
              })"
          ++ lib.optional (
            mimeFor "sway" == null || !lib.hasInfix "thunar.desktop" (mimeFor "sway")
          ) "sway-mimeapps.list does not point inode/directory at thunar"
          ++
            lib.optional (sharedDefault != null)
              "the shared mimeapps.list sets inode/directory (${
                lib.generators.toPretty { } sharedDefault
              }), which would follow the user into GNOME"
        );

      # --- unit shape --------------------------------------------------------
      #
      # The fingerprint used to verify the desktop refactor compared evaluated
      # option *values*. It would have caught a changed ExecStart, and was blind
      # to *added* [Service] directives -- which is exactly how
      # services.greetd.useTextGreeter slipped in and left the greeter drawing a
      # clock onto a console systemd had reset underneath it.
      #
      # So pin the set of directive *names* per section, not their values: store
      # paths and package versions live in values, and pinning those would make
      # this fire on every `nix flake update`. Only units this repo configures
      # directly are listed; nixpkgs-owned units would just churn.
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
        session-anchors = mkCheck "session-anchors" anchorFailures;
        unit-shape = mkCheck "unit-shape" (lib.concatMap checkShape unitShapes);
      }
      # appa is the only host with media services, and only on its own system.
      // lib.optionalAttrs (compatibleHosts ? appa) {
        media-plumbing = mkCheck "media-plumbing" mediaFailures;
      };
    };
}
