{ inputs, self, ... }:
{
  flake-file.inputs.nixos-hardware.url = "github:nixos/nixos-hardware";

  flake.modules.nixos.profile-laptop =
    { pkgs, ... }:
    {
      imports = [
        self.modules.nixos.audio
        self.modules.nixos.bluetooth
        self.modules.nixos.avahi
        self.modules.nixos.printing
        self.modules.nixos.wifi-home
        self.modules.nixos.bundle-host
        inputs.nixos-hardware.nixosModules.common-pc-laptop
        inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
      ];

      environment.systemPackages = [
        # Backlight control (programs.light was removed from nixpkgs)
        pkgs.brightnessctl
        # Interactive battery viewer
        pkgs.batmon
      ];

      # Power management
      powerManagement.enable = true;
      services.power-profiles-daemon.enable = true;
    };
}
