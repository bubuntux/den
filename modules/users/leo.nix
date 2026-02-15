{
  self,
  ...
}:
{
  # Home Manager module for user leo
  flake.homeModules.user-leo =
    { pkgs, ... }:
    {
      # Git user configuration
      programs.git.settings.user = {
        name = "Julio Gutierrez";
        email = "413330+bubuntux@users.noreply.github.com";
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
      users.users.leo = {
        isNormalUser = true;
        description = "Leo";
        initialPassword = "leo";
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

      users.users.bbtux = {
        isNormalUser = true;
        description = "Leo";
        initialPassword = "leo";
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
      home-manager.users.bbtux = {
        imports = [ self.homeModules.user-leo ];
      };
    };
}
