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
    {
      systemd.user.services.home-manager-auto-upgrade = {
        Unit.Description = "Home Manager auto upgrade";
        Service = {
          Type = "oneshot";
          ExecStart = toString (
            pkgs.writeShellScript "hm-auto-upgrade" ''
              ${lib.getExe config.programs.home-manager.package} switch \
                -b bkp \
                --flake github:bubuntux/den#${config.home.username} \
                --refresh
            ''
          );
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
