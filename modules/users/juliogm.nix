{
  self,
  ...
}:
{
  # Home Manager module for user juliogm
  flake.homeModules.user-juliogm = _: {
    imports = with self.homeModules; [
      profile-developer
    ];

    # Git user configuration (decrypted from sops secret via bind mount)
    programs.git.includes = [ { path = "/run/secrets-host/git_config_juliogm"; } ];

    # SSH host configuration (decrypted from sops secret via bind mount)
    programs.ssh.includes = [ "/run/secrets-host/ssh_config_juliogm" ];
  };

  # NixOS module for user juliogm (used inside the work container)
  flake.nixosModules.user-juliogm = _: {
    users.users.juliogm = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [
        "audio"
        "network"
        "pipewire"
        "video"
        "wheel"
      ];
      home = "/home/juliogm";
      createHome = true;
    };

    home-manager.users.juliogm = {
      imports = [ self.homeModules.user-juliogm ];
    };
  };
}
