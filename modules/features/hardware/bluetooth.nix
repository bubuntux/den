{
  flake.nixosModules.bluetooth =
    { lib, ... }:
    {
      services.blueman.enable = true;
      hardware.bluetooth = {
        enable = lib.mkDefault true;
        powerOnBoot = lib.mkDefault true;
      };
    };
}
