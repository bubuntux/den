{
  self,
  inputs,
  ...
}:
{
  # Home Manager module for user juliogm
  flake.homeModules.user-juliogm = _: {
    imports = with self.homeModules; [
      profile-developer
    ];

    # Git user configuration (decrypted from sops secret via bind mount)
    programs.git.includes = [ { path = "/run/secrets-host/git_config"; } ];

    # SSH host configuration (decrypted from sops secret via bind mount)
    programs.ssh.includes = [ "/run/secrets-host/ssh_config" ];
  };

  # Standalone Home Manager configuration for non-NixOS systems
  flake.homeConfigurations.juliogm = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    modules = [
      self.homeModules.user-juliogm
      self.homeModules.nix
      self.homeModules.sops
      (
        { config, lib, ... }:
        {
          home.username = "juliogm";
          home.homeDirectory = "/home/juliogm";
          targets.genericLinux.enable = true;

          sops.secrets.git_config.sopsFile = "${self}/secrets/juliogm.yaml";
          sops.secrets.ssh_config.sopsFile = "${self}/secrets/juliogm.yaml";

          programs.git.includes = lib.mkForce [
            { path = config.sops.secrets.git_config.path; }
          ];
          programs.ssh.includes = lib.mkForce [
            config.sops.secrets.ssh_config.path
          ];
        }
      )
    ];
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
