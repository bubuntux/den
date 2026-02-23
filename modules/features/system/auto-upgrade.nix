{
  flake.nixosModules.auto-upgrade =
    { config, ... }:
    {
      system.autoUpgrade = {
        enable = true;
        flake = "github:bubuntux/den#${config.networking.hostName}";
        dates = "daily";
        operation = "boot";
        allowReboot = false;
        persistent = true;
        randomizedDelaySec = "15min";
      };
    };

  flake.homeModules.auto-upgrade =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      upgradeScript = pkgs.writeShellApplication {
        name = "hm-auto-upgrade";
        runtimeInputs = [
          config.programs.home-manager.package
          pkgs.nix
        ];
        text = ''
          home-manager switch \
            -b bkp \
            --flake github:bubuntux/den#${config.home.username} \
            --refresh
        '';
      };
    in
    {
      systemd.user.services.home-manager-auto-upgrade = {
        Unit.Description = "Home Manager auto upgrade";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe upgradeScript;
        };
      };
      systemd.user.timers.home-manager-auto-upgrade = {
        Unit.Description = "Home Manager auto upgrade timer";
        Timer = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "15min";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
