{ config, ... }:
let
  ifGroupExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  #TODO: replace?
  snowfallorg.users.bbtux = {
    create = true;
    admin = true;
    home.enable = true;
  };

  home-manager.backupFileExtension = "backup";

  users.users.bbtux = {
    isNormalUser = true;
    description = "Julio Guti";
    extraGroups = ifGroupExist [
      "audio"
      "docker"
      "gamemode"
      "input"
      "libvirtd"
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
}
