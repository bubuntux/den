{ inputs, self, ... }:
{

  flake-file.inputs.sops-nix.url = "github:Mic92/sops-nix";
  flake-file.inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";

  flake.nixosModules.sops = _: {
    imports = [ inputs.sops-nix.nixosModules.sops ];
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    home-manager.sharedModules = [ self.homeModules.sops ];
  };

  flake.homeModules.sops = _: {
    imports = [ inputs.sops-nix.homeManagerModules.sops ];
  };

}
