{ self, ... }:
{
  # Home Manager module for developer profile
  flake.homeModules.profile-developer =
    { pkgs, ... }:
    {
      imports = with self.homeModules; [
        bundle-base
        claude-code
        gh
        go
      ];

      # Common development tools
      home.packages = with pkgs; [
        git
        jq # JSON processor
        ripgrep # Fast grep
        fd # Fast find
        tree # Directory listing
      ];
    };

  # NixOS module for developer profile
  flake.nixosModules.profile-developer = _: {
    imports = with self.nixosModules; [ nix-ld ];

    # Add home-manager profile-developer module to shared modules
    home-manager.sharedModules = [ self.homeModules.profile-developer ];
  };
}
