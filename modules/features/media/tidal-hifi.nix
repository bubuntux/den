{
  flake.modules.homeManager.tidal-hifi =
    { pkgs, ... }:
    {
      home.packages = [
        # Tidal appends `--no-sandbox` itself when its `disableSandbox` setting is
        # on, but it does so from JS via app.commandLine.appendSwitch, which runs
        # after Chromium has already set up the sandbox and zygote. Renderers keep
        # starting sandboxed, fail every filesystem syscall (reported misleadingly
        # as "Creating shared memory in /dev/shm ... No such process"), and abort,
        # leaving a blank white window. Only the flag on the real argv takes effect.
        (pkgs.symlinkJoin {
          name = "tidal-hifi-no-sandbox";
          paths = [ pkgs.tidal-hifi ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram "$out/bin/tidal-hifi" --add-flags "--no-sandbox"
          '';
        })
      ];
    };
}
