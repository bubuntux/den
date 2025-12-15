{
  com.all-firmware.nixos = {
    nixpkgs.config.allowUnfree = true;
    hardware.enableAllFirmware = true;
    hardware.enableRedistributableFirmware = true;
  };
}
