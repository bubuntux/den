{ self, ... }:
{
  flake.nixosModules.profile-gaming =
    { pkgs, ... }:
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
          gpu = {
            apply_gpu_optimisations = "accept-responsibility";
            gpu_device = 0;
          };
        };
      };

      # GameScope - SteamOS session compositor
      programs.gamescope = {
        enable = true;
        capSysNice = true;
      };

      # Communication packages
      environment.systemPackages = with pkgs; [
        discord # voice/text chat for gamers
        mumble # low-latency voice chat
      ];

      # Ensure 32-bit support for games
      hardware.graphics.enable32Bit = true;
    };
}
