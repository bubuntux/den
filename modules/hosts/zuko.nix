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
      profile-developer
      dell-precision-5680
      sway
      vpn
      user-bbtux
      firefox
      loupe
      droidcam
      cachix-push

      # Monitor configuration
      {
        home-manager.sharedModules = [
          {
            # Externals are matched by identity ("make model serial"), not the
            # DP-N connector name: the Thunderbolt dock enumerates them on a
            # different DP port each time (DP-5/7, DP-6/8, DP-6/9, ...), so any
            # port-name-based profile only matches some of the time. Identity is
            # stable, so a single docked profile now works regardless of port.
            monitors = [
              # Built-in laptop display. Auxiliary monitor: workspaces 1-3 live
              # here whenever it's on (office setup, or undocked where 4-10 fall
              # back to it since their externals are absent). kanshi disables it
              # entirely when docked at home; see the internal-panel handling in
              # kanshi.nix.
              {
                name = "eDP-1";
                width = 1920;
                height = 1200;
                workspaces = [
                  "1"
                  "2"
                  "3"
                ];
              }
              # Left external — portrait
              {
                name = "Dell Inc. DELL U2722DE J85KV83";
                width = 2560;
                height = 1440;
                transform = "270";
                workspaces = [
                  "1"
                  "2"
                  "3"
                ];
              }
              # Right external — landscape
              {
                name = "Dell Inc. DELL U2722DE 1B5KV83";
                width = 2560;
                height = 1440;
                workspaces = [
                  "4"
                  "5"
                  "6"
                  "7"
                  "8"
                  "9"
                  "10"
                ];
              }
              # Office external — single 1440p monitor, laptop stacked below it.
              # Claims workspaces 4-10 like the home landscape display; the two are
              # never connected at the same time, so no assignment conflict.
              {
                name = "Dell Inc. DELL U2724DE 2KT7QF4";
                width = 2560;
                height = 1440;
                workspaces = [
                  "4"
                  "5"
                  "6"
                  "7"
                  "8"
                  "9"
                  "10"
                ];
              }
              # Office (dual) — landscape on top. Workspaces 4-7; shares those
              # numbers with the home/single-office externals above, which are
              # never connected at the same time as this pair.
              {
                name = "Dell Inc. DELL P2418D 29J0P8AO03XT";
                width = 2560;
                height = 1440;
                workspaces = [
                  "4"
                  "5"
                  "6"
                  "7"
                ];
              }
              # Office (dual) — portrait on the right. Workspaces 8-10.
              {
                name = "Dell Inc. DELL P2418D 29J0P8AO1E9T";
                width = 2560;
                height = 1440;
                transform = "90";
                workspaces = [
                  "8"
                  "9"
                  "10"
                ];
              }
            ];

            monitorProfiles = {
              laptop = [ "eDP-1" ];
              docked = {
                "Dell Inc. DELL U2722DE J85KV83" = "0,0";
                "Dell Inc. DELL U2722DE 1B5KV83" = "1440,669";
              };
              # Office: external on top, laptop centered underneath it (the 1920px
              # panel centered under the 2560px external -> x = (2560-1920)/2 = 320).
              office = {
                "Dell Inc. DELL U2724DE 2KT7QF4" = "0,0";
                "eDP-1" = "320,1440";
              };
              # Office (dual): landscape external on top, laptop right-aligned
              # beneath it (right edge at x=2560 -> x = 2560-1920 = 640), and a
              # tall portrait external on the right spanning both (1440 wide after
              # the 270 rotation, so it sits at x=2560, right of the landscape).
              office-dual = {
                "Dell Inc. DELL P2418D 29J0P8AO03XT" = "0,0";
                "eDP-1" = "640,1440";
                "Dell Inc. DELL P2418D 29J0P8AO1E9T" = "2560,0";
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

          # Keep the network off the boot critical path: NetworkManager-wait-online
          # sat on it, adding ~4s. Nothing on zuko needs the network before the
          # graphical session -- ntpd-rs / geoclue simply retry once the link is up.
          systemd.services.NetworkManager-wait-online.enable = false;

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
          # Preload the FAT/NLS modules the vfat /boot (ESP) mount needs. Without
          # this the kernel auto-loads them mid-mount, and that request stalls
          # ~11s behind nvidia_uvm's slow init (kernel serializes module loading),
          # showing as a "A start job is running for /boot" hang every boot.
          boot.kernelModules = [
            "kvm-intel"
            "vfat"
            "nls_cp437"
            "nls_iso8859-1"
          ];
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
