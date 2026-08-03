{ self, ... }:
{
  flake.modules.nixos.profile-gaming =
    { pkgs, ... }:
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
      key = "den:nixos.profile-gaming";
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
        # No render-offload command here: a host with two GPUs installs its own
        # `gpu-offload`, and Steam's FHS reaches it through the host PATH.
        # See CLAUDE.md, "GPU render offload".
        extraPackages = with pkgs; [ gamescope ];
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
          custom = {
            start = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance &";
            end = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced &";
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
        # Desktop entry for Steam with gamemode
        steam-gamemode-desktop
      ];

      # Ensure 32-bit support for games
      hardware.graphics.enable32Bit = true;
    };
}
