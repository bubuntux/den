{ self, ... }:
{
  flake.nixosModules.profile-gaming =
    { pkgs, lib, ... }:
    let
      # Desktop entry for Steam with gamemode
      steam-gamemode-desktop = pkgs.makeDesktopItem {
        name = "steam-gamemode";
        desktopName = "Steam (GameMode)";
        comment = "Launch Steam with GameMode enabled";
        exec = "gamemoderun steam %U";
        icon = "steam";
        categories = [ "Game" ];
        mimeTypes = [
          "x-scheme-handler/steam"
          "x-scheme-handler/steamlink"
        ];
      };
    in
    {
      # Steam with recommended options
      programs.steam = {
        enable = true;
        # Open firewall for Remote Play
        remotePlay.openFirewall = true;
        # Open firewall for dedicated server
        dedicatedServer.openFirewall = true;
        # Open firewall for local network game transfers
        localNetworkGameTransfers.openFirewall = true;
        # Enable protontricks for Winetricks in Proton games
        protontricks.enable = true;
        # Enable extest for Steam Input on Wayland
        extest.enable = true;
        # Add gamescope and nvidia-offload to Steam's FHS environment
        extraPackages = with pkgs; [
          gamescope
          (writeShellScriptBin "nvidia-offload" ''
            export __NV_PRIME_RENDER_OFFLOAD=1
            export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
            export __GLX_VENDOR_LIBRARY_NAME=nvidia
            export __VK_LAYER_NV_optimus=NVIDIA_only
            exec "$@"
          '')
        ];
      };

      # Steam hardware udev rules (controllers, VR headsets)
      hardware.steam-hardware.enable = true;

      # Xbox controller support
      hardware.xpadneo.enable = true; # Xbox One wireless
      hardware.xone.enable = true; # Xbox One/Series X|S accessories

      # GameMode for performance optimization
      programs.gamemode = {
        enable = true;
        enableRenice = true;
        settings = {
          general = {
            renice = 10;
          };
        };
      };

      # GameScope - SteamOS session compositor
      # capSysNice is omitted because the setuid wrapper it creates
      # cannot inherit capabilities inside Steam's FHS sandbox.
      # GameMode (enableRenice) handles process priority instead.
      programs.gamescope.enable = true;

      # Packages
      environment.systemPackages = with pkgs; [
        # Communication
        discord
        mumble

        # Desktop entry for Steam with gamemode
        steam-gamemode-desktop
      ];

      # Ensure 32-bit support for games
      hardware.graphics.enable32Bit = true;
    };
}
