{ self, ... }:
{
  # A booted-VM test for the login path, which is the one thing evaluation
  # cannot check. `desktop-matrix` proves the modules *decide* correctly --
  # which sessions are registered, which greeter is enabled -- but it cannot
  # tell you the greeter actually draws a usable prompt, which is the failure
  # that reached a real machine once (a clock on a black screen, with every
  # evaluated option value correct).
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
    };
}
