{
  self,
  ...
}:
{
  # Home Manager module for user bbtux
  flake.homeModules.user-bbtux = _: {
    # Git user configuration
    programs.git.settings.user = {
      name = "Julio Gutierrez";
      email = "413330+bubuntux@users.noreply.github.com";
    };

    # jj shares the same identity (mirrors the git config above)
    programs.jujutsu.settings.user = {
      name = "Julio Gutierrez";
      email = "413330+bubuntux@users.noreply.github.com";
    };

    # Sign own commits with the SSH key
    programs.jujutsu.settings.signing = {
      behavior = "own";
      backend = "ssh";
      key = "~/.ssh/id_ed25519.pub";
    };
  };

  # NixOS module for user bbtux
  flake.nixosModules.user-bbtux =
    { config, ... }:
    let
      # Only add groups that exist on the system
      ifGroupExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
    in
    {
      users.users.bbtux = {
        isNormalUser = true;
        description = "Julio Guti";
        initialPassword = "bbtux";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfnT06gNHha8xJzYX7aFrszzdKraUp2Dv7iJvCNuBOE bbtux@zuko"
        ];
        extraGroups = ifGroupExist [
          "audio"
          "docker"
          "gamemode"
          "input"
          "libvirtd"
          "lpadmin"
          "lxd"
          "media"
          "network"
          "networkmanager"
          "pipewire"
          "plugdev"
          "podman"
          "video"
          "wheel"
        ];
      };

      home-manager.users.bbtux = {
        imports = [ self.homeModules.user-bbtux ];
      };
    };
}
