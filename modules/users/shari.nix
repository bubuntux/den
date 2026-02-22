{ self, ... }:
{

  flake.nixosModules.user-shari =
    { config, ... }:
    {
      sops.secrets.shari_password_hash = {
        sopsFile = "${self}/secrets/shari.yaml";
        neededForUsers = true;
      };
      services.displayManager.autoLogin.user = "shari";
      users.users.shari = {
        isNormalUser = true;
        description = "Sharai C";
        hashedPasswordFile = config.sops.secrets.shari_password_hash.path;
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfnT06gNHha8xJzYX7aFrszzdKraUp2Dv7iJvCNuBOE"
        ];
      };
      home-manager.users.shari = {
      };
    };

}
