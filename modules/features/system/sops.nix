{ inputs, self, ... }:
{

  flake-file.inputs.sops-nix.url = "github:Mic92/sops-nix";
  flake-file.inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";

  flake.modules = {
    nixos.sops =
      { lib, ... }:
      {
        key = "den:nixos.sops";
        imports = [ inputs.sops-nix.nixosModules.sops ];
        sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        home-manager.sharedModules = [ self.modules.homeManager.sops ];

        # VM builds get a fresh host SSH key that isn't on any sops keyring,
        # so out-of-the-box they can't decrypt anything. The host-vm wrapper
        # in modules/core/host-vm.nix exposes the invoking user's ~/.ssh as a
        # 9p share with tag `user-ssh`; here we mount it inside the VM and
        # point sops at it. Decryption then works for any secret encrypted to
        # the developer's age key, regardless of which user is launching the VM.
        virtualisation.vmVariant = {
          # virtualisation.fileSystems is the VM-scoped twin of fileSystems —
          # it's where qemu-vm.nix expects per-VM mounts (this is also what
          # virtualisation.sharedDirectories writes to under the hood).
          virtualisation.fileSystems."/run/host-ssh" = {
            device = "user-ssh";
            fsType = "9p";
            neededForBoot = true;
            options = [
              "trans=virtio"
              "version=9p2000.L"
              "ro"
              "msize=65536"
              "nofail"
            ];
          };
          sops.age.sshKeyPaths = lib.mkForce [ "/run/host-ssh/id_ed25519" ];
        };
      };

    homeManager.sops = {
      key = "den:homeManager.sops";
      imports = [ inputs.sops-nix.homeManagerModules.sops ];
    };

  };
}
