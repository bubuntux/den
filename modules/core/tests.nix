{ self, ... }:
{
  # Booted-VM tests for the login path: test-greeter, test-session (greetd) and
  # test-session-gdm. Deliberately packages, not flake checks. See CLAUDE.md,
  # "Booted-VM tests".
  perSystem =
    { pkgs, lib, ... }:
    let
      greeterTest = pkgs.testers.runNixOSTest {
        name = "greeter-renders";

        nodes.machine =
          { lib, ... }:
          {
            imports = with self.modules.nixos; [
              home-manager
              desktop-options
              sway
              login-greetd
            ];

            den.desktop = {
              environments = [ "sway" ];
              loginManager = "greetd";
            };
            # Mirrors zuko. The command is multi-word, so the greeter only
            # renders if greetd.nix quotes it into one --cmd argument.
            services.displayManager.defaultSession = "sway";

            users.users.alice = {
              isNormalUser = true;
              password = "test";
            };

            virtualisation.memorySize = 2048;

            # Kernel messages would scribble over the TUI; the framework pins
            # loglevel=7, real hosts boot quiet.
            boot.consoleLogLevel = lib.mkForce 0;
            boot.kernelParams = [ "quiet" ];

            # The plymouth -> greeter console handover is part of the path.
            boot.plymouth.enable = true;
          };

        # Assert on pixels, not on config values.
        enableOCR = true;

        testScript =
          { nodes, ... }:
          ''
            machine.start()
            machine.wait_for_unit("greetd.service")

            # "Username" is tuigreet's field label. Polling for the process is
            # racy (greetd is Type=idle and re-execs the greeter).
            machine.wait_for_text("Username")
            machine.succeed("systemctl is-active greetd.service")

            # Readable *as the greeter user*, not merely present in the store.
            machine.succeed(
                "su -s /bin/sh greeter -c "
                "'test -r ${nodes.machine.services.displayManager.sessionData.desktops}"
                "/share/wayland-sessions/sway.desktop'"
            )

            # ... and it has to persist: drawing once then losing the console
            # still leaves a black screen.
            machine.sleep(10)
            machine.wait_for_text("Username")
            machine.screenshot("greeter")
          '';
      };

      # Boots the real login path -- greeter autologin -> sway -> the session's
      # own units -- and asserts the things only a running session can show.
      #
      # Once per greeter: greetd runs a command line, GDM execs the .desktop
      # entry, and only the former was covered.
      mkSessionTest =
        {
          testName,
          loginManager,
          loginModule,
          greeterUnit,
          memorySize ? 2048,
          bar ? "waybar",
        }:
        let
          # waybar names the session it was built for; ironbar is one bar for
          # all of them. ironbar-weather is left out: the VM has no route to
          # the forecast API, and the point here is that the bar stays up.
          barUnits =
            if bar == "ironbar" then
              [
                "ironbar"
                "ironbar-vars"
              ]
            else
              [ "waybar-sway" ];
        in
        pkgs.testers.runNixOSTest {
          name = testName;

          nodes.machine =
            { lib, ... }:
            {
              imports = with self.modules.nixos; [
                home-manager
                desktop-options
                sway
                loginModule
              ];

              den.desktop = {
                environments = [ "sway" ];
                inherit loginManager bar;
              };

              # Autologin: the prompt itself is test-greeter's job.
              services.displayManager = {
                defaultSession = "sway";
                autoLogin = {
                  enable = true;
                  user = "alice";
                };
              };

              users.users.alice = {
                isNormalUser = true;
                password = "test";
                # Pinned: the test names /run/user/1000 from root.
                uid = 1000;
              };

              home-manager.users.alice = { };

              # Schema and values together, the way a host pushes them. Without
              # monitors, kanshi is not enabled and the VM stops resembling a
              # real machine; the name need not match the virtio output.
              home-manager.sharedModules = [
                {
                  imports = [ self.modules.homeManager.monitors ];
                  monitors = [
                    {
                      name = "Virtual-1";
                      primary = true;
                      width = 1280;
                      height = 800;
                    }
                  ];
                }
              ];

              # Both lifted from nixpkgs' nixos/tests/sway.nix: no GLES2 in the
              # VM, and `-vga std` gives no DRM node sway can drive.
              environment.variables.WLR_RENDERER = "pixman";
              virtualisation.qemu.options = [ "-vga none -device virtio-gpu-pci" ];
              virtualisation.memorySize = memorySize;

              boot.consoleLogLevel = lib.mkForce 0;
              boot.kernelParams = [ "quiet" ];
            };

          testScript = ''
            # `su alice -c` alone gets no user bus, hence the explicit runtime dir.
            def user(cmd):
                return f"su alice -c 'XDG_RUNTIME_DIR=/run/user/1000 {cmd}'"

            # 180s throughout: sway needs ~40s under pixman, and 60s failed about
            # half the time.
            def wait_active(unit):
                machine.wait_until_succeeds(
                    user(f"systemctl --user is-active {unit}"), timeout=180
                )

            machine.start()
            machine.wait_for_unit("${greeterUnit}")

            # Type=notify, so this goes active only once `uwsm finalize` ran.
            wait_active("wayland-session@sway.target")
            wait_active("den-session.target")

            # The bar follows its own target (an anchor for waybar, the shared
            # one for ironbar), kanshi and swayidle the shared target, so both
            # paths are covered. gammastep is excluded: geoclue has no location
            # in a VM, so it crash-loops regardless.
            companions = [${
              lib.concatMapStringsSep ", " (u: "\"${u}\"") (
                barUnits
                ++ [
                  "kanshi"
                  "swayidle"
                ]
              )
            }]
            for unit in companions:
                wait_active(f"{unit}.service")

            # NRestarts, because `is-active` is also true of a bar that starts,
            # dies and gets restarted with nothing on screen.
            machine.sleep(10)
            for unit in companions:
                restarts = machine.succeed(
                    user(f"systemctl --user show {unit}.service -p NRestarts --value")
                ).strip()
                state = machine.succeed(
                    user(f"systemctl --user is-active {unit}.service")
                ).strip()
                assert restarts == "0" and state == "active", (
                    f"{unit}.service is {state} after {restarts} restart(s); "
                    "it came up and did not stay up"
                )

            # Empty here means `<desktop>-mimeapps.list` is never read.
            env = machine.succeed(user("systemctl --user show-environment"))
            assert "XDG_CURRENT_DESKTOP=sway" in env, (
                f"XDG_CURRENT_DESKTOP is not sway in the session environment:\n{env}"
            )

            machine.screenshot("session")
          '';
        };
    in
    {
      packages = {
        test-greeter = greeterTest;

        # zuko's shape.
        test-session = mkSessionTest {
          testName = "sway-session-comes-up";
          loginManager = "greetd";
          loginModule = self.modules.nixos.login-greetd;
          greeterUnit = "greetd.service";
        };

        # katara's shape. 4G because GDM's own greeter is gnome-shell.
        test-session-gdm = mkSessionTest {
          testName = "sway-session-comes-up-on-gdm";
          loginManager = "gdm";
          loginModule = self.modules.nixos.login-gdm;
          greeterUnit = "display-manager.service";
          memorySize = 4096;
        };

        # The other bar, on the cheaper greeter: nothing in an evaluation shows
        # that a bar following den-session.target rather than an anchor really
        # comes up, nor that its producers survive racing the daemon.
        test-session-ironbar = mkSessionTest {
          testName = "sway-session-comes-up-with-ironbar";
          loginManager = "greetd";
          loginModule = self.modules.nixos.login-greetd;
          greeterUnit = "greetd.service";
          bar = "ironbar";
        };
      };
    };
}
