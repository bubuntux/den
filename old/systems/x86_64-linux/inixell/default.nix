{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./dell-precision-5680.nix
    ./work.nix
    ./desktop
  ];

  networking.nftables.enable = true;
  hardware = {
    graphics.enable32Bit = true;

    intel-gpu-tools.enable = true;
    intelgpu.driver = "xe";

    keyboard.zsa.enable = true;
    bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };
  };

  security.rtkit.enable = true;
  systemd.services.rtkit-daemon.serviceConfig = {
    Nice = -11; # A lower "nice" value means higher priority. Ranges from 19 to -20.
    CPUSchedulingPolicy = "fifo"; # A real-time scheduling policy.
    CPUSchedulingPriority = 50; # A high priority for the real-time policy.
  };

  services = {
    blueman.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;

      wireplumber = {
        enable = true;
      };
    };
    pulseaudio.enable = lib.mkForce false;

    printing.enable = true;

    avahi = {
      enable = true;
      ipv4 = true;
      ipv6 = true;
      nssmdns4 = true;
      nssmdns6 = true;
      openFirewall = true;
    };
  };

  programs = {
    light.enable = true; # TODO: blacklight

    gamemode = {
      enable = true;
      settings.general.inhibit_screensaver = 1;
    };

    nix-ld = {
      enable = true;
      libraries = with pkgs; [
      ];
    };

    localsend = {
      enable = true;
      openFirewall = true;
    };

  };

  powerManagement.enable = true;

  system.stateVersion = "25.05";
}
