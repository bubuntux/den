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
    { config, ... }:
    let
      # Only add groups that exist on the system
      ifGroupExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
    in
    {
      # Enable geoclue2 for gammastep location provider
      services.geoclue2.enable = true;

      users.users.leo = {
        isNormalUser = true;
        description = "Leo";
        extraGroups = ifGroupExist [
          "audio"
          "docker"
          "gamemode"
          "input"
          "libvirtd"
          "lpadmin"
          "lxd"
          "network"
          "networkmanager"
          "pipewire"
          "plugdev"
          "podman"
          "video"
          "wheel"
        ];
      };

      home-manager.users.leo = {
        imports = [ self.homeModules.user-leo ];
      };
    };
}
