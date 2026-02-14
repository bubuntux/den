{ self, ... }:
{
  # Home Manager module for developer profile
  flake.homeModules.profile-developer =
    { pkgs, ... }:
    {
      imports = with self.homeModules; [
        claude-code
      ];

      # Common development tools
      home.packages = with pkgs; [
        git
        gh # GitHub CLI
        jq # JSON processor
        ripgrep # Fast grep
        fd # Fast find
        tree # Directory listing
      ];
    };

  # NixOS module for developer profile
  flake.nixosModules.profile-developer = {
    imports = with self.nixosModules; [
      claude-code
    ];

    # Add home-manager profile-developer module to shared modules
    home-manager.sharedModules = [ self.homeModules.profile-developer ];
  };
}
