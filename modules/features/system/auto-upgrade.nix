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
}
