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
        # Add gamescope to Steam's extra packages
        extraPackages = with pkgs; [
          gamescope
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
      programs.gamescope = {
        enable = true;
        capSysNice = true;
      };

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
