{ inputs, self, ... }:
{
  flake-file.inputs.nixos-hardware.url = "github:nixos/nixos-hardware";

  flake.nixosModules.profile-laptop = {
    imports = [
      self.nixosModules.audio
      self.nixosModules.bluetooth
      self.nixosModules.printing
      self.nixosModules.power-profile-auto
      self.nixosModules.bundle-base
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
