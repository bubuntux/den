{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.katara = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with self.nixosModules; [
      profile-laptop
      profile-wife
      (
        { pkgs, ... }:
        {
          imports = [ ./_katara-hardware-configuration.nix ];

          networking.hostName = "katara";
          system.stateVersion = "25.11";

          # Enable networking
          networking.networkmanager.enable = true;

          # Install firefox.
          programs.firefox.enable = true;

        }
      )
    ];
  };
}
