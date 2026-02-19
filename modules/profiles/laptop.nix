{ inputs, self, ... }:
{
  flake-file.inputs.nixos-hardware.url = "github:nixos/nixos-hardware";

  flake.nixosModules.profile-laptop = _: {
    imports = [
      self.nixosModules.audio
      self.nixosModules.bluetooth
      self.nixosModules.printing
      self.nixosModules.bundle-host
      inputs.nixos-hardware.nixosModules.common-pc-laptop
      inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    ];

    # Backlight control
    programs.light.enable = true;

    # Power management
    powerManagement.enable = true;
    services.power-profiles-daemon.enable = true;
  };
}
