{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.katara = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with self.nixosModules; [
      profile-wife
      (
        { pkgs, ... }:
        {
          imports = [ ./_katara-hardware-configuration.nix ];

          networking.hostName = "katara";
          system.stateVersion = "25.11";

          # Enable networking
          networking.networkmanager.enable = true;

          # Define a user account. Don't forget to set a password with ‘passwd’.
          users.users.dona = {
            isNormalUser = true;
            description = "Dona";
            extraGroups = [
              "networkmanager"
              "wheel"
            ];
            packages = with pkgs; [
              helix
            ];
          };

          # Install firefox.
          programs.firefox.enable = true;

        }
      )
    ];
  };
}
