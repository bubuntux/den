{ inputs, self, ... }:
{
  flake-file.inputs.nixos-hardware.url = "github:nixos/nixos-hardware";

  flake.nixosModules.profile-laptop =
    { pkgs, ... }:
    {
      imports = [
        self.nixosModules.audio
        self.nixosModules.bluetooth
        self.nixosModules.avahi
        self.nixosModules.printing
        self.nixosModules.wifi-home
        self.nixosModules.bundle-host
        inputs.nixos-hardware.nixosModules.common-pc-laptop
        inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
      ];

      # Backlight control (programs.light was removed from nixpkgs)
      environment.systemPackages = [ pkgs.brightnessctl ];

      # Power management
      powerManagement.enable = true;
      services.power-profiles-daemon.enable = true;
    };
}
