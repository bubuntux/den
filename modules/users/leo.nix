{
  self,
  ...
}:
{
  # Home Manager module for user leo
  flake.homeModules.user-leo =
    { pkgs, ... }:
    {
      # Gammastep for screen color temperature (night light)
      services.gammastep = {
        enable = true;
        provider = "geoclue2";
        temperature = {
          day = 6500;
          night = 4000;
        };
      };

      # User packages
      home.packages = with pkgs; [
        # Utilities
        ouch # compression/decompression
        xarchiver # GUI archive manager

        # Creative
        gimp-with-plugins # image editor
        simple-scan # scanner

        # Media
        tidal-hifi # music streaming
      ];
    };

  # NixOS module for user leo
  flake.nixosModules.user-leo =
    { ... }:
    {
      # Enable geoclue2 for gammastep location provider
      services.geoclue2.enable = true;

      users.users.leo = {
        isNormalUser = true;
        description = "Leo";
        extraGroups = [
          "networkmanager"
          "wheel"
          "video" # for brightness control
          "audio" # for audio control
        ];
      };

      home-manager.users.leo = {
        imports = [ self.homeModules.user-leo ];
      };
    };
}
