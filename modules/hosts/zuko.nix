{
  #   inputs,
  #   self,
  #   ...
  # }:
  # {
  #   flake.nixosConfigurations.zuko = inputs.nixpkgs.lib.nixosSystem {
  #     modules = [
  #       self.nixosModules.zuko
  #     ];

  #   };

  #   flake.nixosModules.zuko =
  #     { pkgs, lib, ... }:
  #     {
  #       nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  #       system.stateVersion = "25.11";
  #     };
}
