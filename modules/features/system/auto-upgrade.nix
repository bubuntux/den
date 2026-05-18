{
  flake.nixosModules.auto-upgrade =
    { config, lib, ... }:
    {
      # Tunable defaults — hosts can override any of these without mkForce.
      # Cautious profile: daily build, stage for next boot, never auto-reboot.
      # See modules/hosts/appa.nix for a more autonomous override (weekly,
      # auto-reboot in a quiet window).
      system.autoUpgrade = {
        enable = true;
        flake = "github:bubuntux/den#${config.networking.hostName}";
        dates = lib.mkDefault "daily";
        operation = lib.mkDefault "boot";
        allowReboot = lib.mkDefault false;
        persistent = lib.mkDefault true;
        randomizedDelaySec = lib.mkDefault "15min";
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
        Unit = {
          Description = "Home Manager auto upgrade";
          X-SwitchMethod = "keep-old";
        };
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
