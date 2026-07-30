{ self, ... }:
{
  # Home Manager module for developer profile
  flake.modules = {
    homeManager.profile-developer =
      { pkgs, ... }:
      {
        imports = with self.modules.homeManager; [
          bundle-base
          claude-code
          devenv
          difftastic
          gh
          go
          jujutsu
        ];

        # Common development tools
        home.packages = with pkgs; [
          git
          jq # JSON processor
          ripgrep # Fast grep
          fd # Fast find
          tree # Directory listing
          mermaid-cli # Diagram generation from text
        ];
      };

    # NixOS module for developer profile
    nixos.profile-developer = _: {
      imports = with self.modules.nixos; [ nix-ld ];

      # Add home-manager profile-developer module to shared modules
      home-manager.sharedModules = [ self.modules.homeManager.profile-developer ];
    };
  };
}
