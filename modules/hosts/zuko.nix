{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.zuko = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };
    system = "x86_64-linux";
    modules = with self.nixosModules; [
      profile-laptop
      profile-gaming
      profile-work
      dell-precision-5680
      sway
      vpn
      user-leo

      # Monitor configuration
      {
        home-manager.sharedModules = [
          {
            monitors = [
              # Built-in laptop display
              {
                name = "eDP-1";
                width = 1920;
                height = 1200;
                workspaces = [
                  "8"
                  "9"
                  "10"
                ];
              }
              # External monitors (dock ports vary)
              {
                name = "DP-3";
                width = 2560;
                height = 1440;
              }
              {
                name = "DP-4";
                width = 2560;
                height = 1440;
              }
              {
                name = "DP-5";
                width = 2560;
                height = 1440;
                transform = "270";
                workspaces = [
                  "1"
                  "2"
                  "3"
                ];
              }
              {
                name = "DP-6";
                width = 2560;
                height = 1440;
                transform = "270";
                workspaces = [
                  "1"
                  "2"
                  "3"
                ];
              }
              {
                name = "DP-7";
                width = 2560;
                height = 1440;
                workspaces = [
                  "4"
                  "5"
                  "6"
                  "7"
                ];
              }
              {
                name = "DP-8";
                width = 2560;
                height = 1440;
                workspaces = [
                  "4"
                  "5"
                  "6"
                  "7"
                ];
              }
              {
                name = "DP-9";
                width = 2560;
                height = 1440;
                workspaces = [
                  "4"
                  "5"
                  "6"
                  "7"
                ];
              }
            ];

            monitorProfiles = {
              laptop = [ "eDP-1" ];
              office = {
                "DP-3" = "0,0";
                "DP-4" = "2560,0";
                "eDP-1" = "1440,1440";
              };
              workstation5-7 = {
                "DP-5" = "0,0";
                "DP-7" = "1440,0";
                "eDP-1" = "1440,1440";
              };
              workstation6-8 = {
                "DP-6" = "0,0";
                "DP-8" = "1440,0";
                "eDP-1" = "1440,1440";
              };
              workstation6-9 = {
                "DP-6" = "0,0";
                "DP-9" = "1440,0";
                "eDP-1" = "1440,1440";
              };
            };
          }
        ];
      }

      (
        {
          config,
          lib,
          modulesPath,
          ...
        }:
        {
          networking.hostName = "zuko";
          system.stateVersion = "25.11";

          imports = [
            (modulesPath + "/installer/scan/not-detected.nix")
          ];

          boot.initrd.availableKernelModules = [
            "xhci_pci"
            "ahci"
            "thunderbolt"
            "nvme"
            "usb_storage"
            "sd_mod"
            "rtsx_pci_sdmmc"
          ];
          boot.initrd.kernelModules = [ ];
          boot.kernelModules = [ "kvm-intel" ];
          boot.extraModulePackages = [ ];

          fileSystems."/" = {
            device = "/dev/disk/by-uuid/cb3960d5-892b-4c85-a601-eb2458a6cd0d";
            fsType = "ext4";
          };

          fileSystems."/boot" = {
            device = "/dev/disk/by-uuid/E362-89D9";
            fsType = "vfat";
            options = [
              "fmask=0077"
              "dmask=0077"
            ];
          };

          swapDevices = [
            { device = "/dev/disk/by-uuid/b917e6de-c591-42f3-8047-79289917afc4"; }
          ];

          nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
          hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
          hardware.keyboard.zsa.enable = true;
          hardware.intel-gpu-tools.enable = true;
        }
      )
    ];
  };
}
