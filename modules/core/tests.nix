{ self, ... }:
{
  # Booted-VM tests for the login path, which is the one thing evaluation cannot
  # check. Two of them, covering the two halves:
  #
  #   test-greeter    the greeter draws a usable prompt
  #   test-session    logging in actually produces a working session
  #
  # `desktop-matrix` proves the modules *decide* correctly -- which sessions are
  # registered, which greeter is enabled -- and `session-anchors` proves the
  # units are *wired* to the right target. Neither can tell you a session comes
  # up, which is the failure that reached a real machine once (a clock on a black
  # screen, with every evaluated option value correct).
  #
  # Scope, honestly: this test does NOT reproduce that failure. Enabling
  # services.greetd.useTextGreeter -- the suspected cause -- passes here, with
  # and without plymouth. Whatever the real interaction was, it needs something
  # this environment lacks (the VM app runs qemu with `-vga virtio -display
  # gtk,gl=on`; the test driver gets a bochs framebuffer). So treat this as
  # "the greeter renders and keeps rendering", not as a regression test for
  # that specific option -- `unit-shape` in checks.nix is what pins the unit.
  #
  # Deliberately NOT a flake check. `nix flake check` gates .github/workflows
  # ci.yml's `build` job, and `heal` only fires when `build` *fails*; anything
  # heavy or flaky in `checks` turns a caddy-hash drift into a skipped build and
  # a dead self-heal (see modules/core/checks.nix). Run it on purpose:
  #
  #   nix build .#test-greeter
  #
  # before touching features/desktop/login/ or the greetd command line.
  perSystem =
    { pkgs, ... }:
    {
      packages.test-greeter = pkgs.testers.runNixOSTest {
        name = "greeter-renders";

        nodes.machine =
          { lib, ... }:
          {
            imports = with self.modules.nixos; [
              # home-manager: desktop-options binds each user's session config
              # through home-manager.users, so the option has to exist.
              home-manager
              desktop-options
              sway
              login-greetd
            ];

            den.desktop = {
              environments = [ "sway" ];
              loginManager = "greetd";
            };
            services.displayManager.defaultSession = "sway";

            users.users.alice = {
              isNormalUser = true;
              password = "test";
            };

            # tuigreet is a TUI on tty1; the test driver needs a framebuffer to
            # screenshot and OCR it.
            virtualisation.memorySize = 2048;

            # The test framework boots with loglevel=7 on console=tty0, which
            # scribbles kernel messages straight over any TUI -- the first
            # screenshot of this test was pure dmesg. Real hosts boot quiet behind
            # plymouth, so quiet the console here too; otherwise the test measures
            # the framework's console settings rather than the greeter. mkForce
            # because test-instrumentation.nix pins it to 7 for debuggability;
            # kernel messages are still available from the journal.
            boot.consoleLogLevel = lib.mkForce 0;
            boot.kernelParams = [ "quiet" ];

            # Real hosts boot behind plymouth, and the greetd unit orders itself
            # after plymouth-quit-wait.service, so the console handover from
            # plymouth to the greeter is part of the path under test.
            boot.plymouth.enable = true;
          };

        # Reads the console with tesseract. This is the only way to assert on
        # what the greeter put on screen rather than on what it was configured
        # to do.
        enableOCR = true;

        testScript =
          { nodes, ... }:
          ''
            machine.start()
            machine.wait_for_unit("greetd.service")

            # Assert on the rendered UI, not on a process. greetd is Type=idle
            # (systemd delays the exec until the boot queue drains) and it then
            # re-execs the greeter through a `greetd --session-worker`, so
            # polling for a tuigreet process is racy -- an earlier draft of this
            # test saw one at 0.1s and none at 5s, with nothing actually wrong.
            #
            # "Username" is tuigreet's own field label, and it is the right
            # thing to look for: the failure that reached a real machine showed
            # the *clock* and no prompt, so asserting on the clock -- or on any
            # configuration value -- would have passed.
            machine.wait_for_text("Username")
            machine.succeed("systemctl is-active greetd.service")

            # The session list has to be readable *as the greeter user*, not
            # just present in the store.
            machine.succeed(
                "su -s /bin/sh greeter -c "
                "'test -r ${nodes.machine.services.displayManager.sessionData.desktops}"
                "/share/wayland-sessions/sway.desktop'"
            )

            # ... and the UI has to persist. A greeter that draws once and then
            # loses the console would satisfy the check above and still leave a
            # black screen in front of the user.
            machine.sleep(10)
            machine.wait_for_text("Username")
            machine.screenshot("greeter")
          '';
      };

      # Boots the real login path -- greetd autologin -> sway -> the session's
      # own units -- and asserts the things only a running session can show.
      #
      # `session-anchors` (checks.nix) proves every companion is *wired* to
      # den-session.target. That is a statement about generated unit files; it
      # cannot tell you the anchor is ever reached, that the companions survive
      # being started, or what XDG_CURRENT_DESKTOP ends up as -- and that last
      # one decides whether `sway-mimeapps.list` is read at all, since XDG names
      # the file after the value of that variable.
      #
      # It also exists to make replacing the session plumbing safe. Swapping
      # Home Manager's sway-session.target for uwsm's wayland-session@sway.target
      # changes exactly the four facts asserted below, so this is the test that
      # says the swap preserved the session rather than merely evaluating.
      #
      #   nix build .#test-session
      packages.test-session = pkgs.testers.runNixOSTest {
        name = "sway-session-comes-up";

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

            # Autologin so the test drives a session rather than a prompt; the
            # prompt itself is test-greeter's job. This is also the greetd path
            # that ignores defaultSession and runs
            # den.desktop.sessionCommands.sway, so the bare `sway` command is
            # under test too.
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
              # Pinned so the test can name /run/user/1000 when reaching into
              # the session as root.
              uid = 1000;
            };

            # den.desktop.environments pushes homeManager.sway at every user, so
            # the home only has to exist.
            home-manager.users.alice = { };

            # A display layout, pushed the way a host pushes it -- schema and
            # values together, since only Sway users import the modules that
            # read it. Without one, kanshi is not enabled (see
            # features/desktop/kanshi.nix) and this VM would stop resembling a
            # real machine in the one place that matters here. The name does not
            # have to match the virtio output: an unmatched profile leaves
            # kanshi running and waiting, which is the state under test.
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

            # wlroots cannot use the GLES2 renderer in this VM, and the default
            # `-vga std` gives no DRM node sway can drive. Both settings are
            # lifted from nixpkgs' own sway test (nixos/tests/sway.nix).
            environment.variables.WLR_RENDERER = "pixman";
            virtualisation.qemu.options = [ "-vga none -device virtio-gpu-pci" ];
            virtualisation.memorySize = 2048;

            boot.consoleLogLevel = lib.mkForce 0;
            boot.kernelParams = [ "quiet" ];
          };

        testScript = ''
          # Reach into alice's session from root. `su alice -c` alone gets no
          # user bus, so the runtime dir has to be named explicitly.
          def user(cmd):
              return f"su alice -c 'XDG_RUNTIME_DIR=/run/user/1000 {cmd}'"

          # Every wait gets the same generous budget. Sway needs ~40s to come up
          # under the pixman software renderer, and the companions land in a
          # burst after it, so a tighter budget on the later units only measures
          # how loaded the builder is -- an earlier draft used 60s and failed
          # that way about half the time.
          def wait_active(unit):
              machine.wait_until_succeeds(
                  user(f"systemctl --user is-active {unit}"), timeout=180
              )

          machine.start()
          machine.wait_for_unit("greetd.service")

          # 1. The anchor is reached. Everything else hangs off this, so if the
          #    session dies at startup this is where it shows.
          wait_active("sway-session.target")

          # 2. The shared target follows it. This is the unit that ~35 upstream
          #    Home Manager modules bind to through wayland.systemd.target.
          wait_active("den-session.target")

          # 3. The companions actually run. waybar is the one a user would
          #    notice missing, and it is bound to sway-session.target directly
          #    rather than to den-session.target; kanshi and swayidle come
          #    through the shared target, so between them both paths are
          #    covered.
          #
          #    gammastep is deliberately excluded: its provider is geoclue,
          #    which has no location to give in a VM, so it crash-loops here and
          #    would make the test measure the environment rather than the
          #    session.
          companions = ["waybar", "kanshi", "swayidle"]
          for unit in companions:
              wait_active(f"{unit}.service")

          # ... and they have to still be running a moment later. `is-active`
          # alone is satisfied by a service that starts, dies and gets restarted
          # -- which is precisely how a bar can be "active" with nothing on
          # screen. NRestarts is what separates the two.
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

          # 4. XDG_CURRENT_DESKTOP, as the session manager sees it. This is the
          #    value XDG turns into `<desktop>-mimeapps.list`, so if it is empty
          #    the per-desktop file manager association silently never applies --
          #    and nothing at evaluation time can tell you that.
          env = machine.succeed(user("systemctl --user show-environment"))
          assert "XDG_CURRENT_DESKTOP=sway" in env, (
              f"XDG_CURRENT_DESKTOP is not sway in the session environment:\n{env}"
          )

          machine.screenshot("session")
        '';
      };
    };
}
