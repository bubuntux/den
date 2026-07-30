{ self, inputs, ... }:
{
  # `nix flake check` used to build only treefmt and the flake-file check, so it
  # proved formatting and nothing else -- no host was built and no assertion was
  # ever exercised. These checks close that gap:
  #
  #   host-<name>        the host actually builds
  #   desktop-matrix     the DE/DM combinations produce the expected config
  #   desktop-rejects    the invalid combinations are refused
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
      # --- host builds -------------------------------------------------------

      compatibleHosts = lib.filterAttrs (
        _: cfg: cfg.config.nixpkgs.system == system
      ) self.nixosConfigurations;

      hostChecks = lib.mapAttrs' (
        name: cfg: lib.nameValuePair "host-${name}" cfg.config.system.build.toplevel
      ) compatibleHosts;

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
      };

      cases = [
        {
          name = "sway on greetd (what zuko and katara run)";
          modules = [
            {
              den.desktop = {
                environments = [ "sway" ];
                loginManager = "greetd";
                users.bbtux = "sway";
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
            hmUsers = [ "bbtux" ];
          };
          # Preserves the pre-split behaviour: greetd ignores defaultSession
          # upstream, so den.desktop.sessionCommands has to supply --cmd.
          cmdContains = "--cmd sway";
        }
        {
          name = "sway + gnome on greetd, one environment per user";
          modules = [
            {
              den.desktop = {
                environments = [
                  "sway"
                  "gnome"
                ];
                loginManager = "greetd";
                users = {
                  bbtux = "sway";
                  shari = "gnome";
                };
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
            hmUsers = [
              "bbtux"
              "shari"
            ];
          };
          # Per-user session memory is what lets two users land in different
          # desktops from the same greeter.
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
                users.bbtux = "gnome";
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
                users.bbtux = "sway";
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
          name = "profile-wife: gnome on gdm with autologin";
          modules = [
            self.modules.nixos.bundle-host
            self.modules.nixos.profile-wife
          ];
          expect = {
            sessions = [ "gnome" ];
            greetd = false;
            gdm = true;
            sway = false;
            gnome = true;
            autoLoginUser = "shari";
            hmUsers = [ "shari" ];
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
          name = "a user assigned an environment that is not installed";
          modules = [
            {
              den.desktop = {
                environments = [ "sway" ];
                users.bbtux = "gnome";
              };
            }
            self.modules.nixos.bundle-desktop
          ];
        }
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

      mkCheck =
        name: found:
        if found == [ ] then
          pkgs.runCommand "check-${name}-ok" { } "touch $out"
        else
          throw "${name}: ${toString (lib.length found)} failure(s)\n  ${lib.concatStringsSep "\n  " found}";
    in
    {
      checks = hostChecks // {
        desktop-matrix = mkCheck "desktop-matrix" (lib.concatMap checkCase cases);
        desktop-rejects = mkCheck "desktop-rejects" (lib.concatMap checkReject rejects);
      };
    };
}
