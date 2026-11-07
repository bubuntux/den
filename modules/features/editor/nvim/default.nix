{ self, inputs, ... }:
{
  flake-file.inputs.nixvim = {
    url = "github:nix-community/nixvim/nixos-26.05";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  perSystem =
    { pkgs, system, ... }:
    {
      packages.neovim = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
        inherit pkgs;
        module = self.modules.nixvim.neovim;
      };
    };

  flake.modules.homeManager.neovim = {
    key = "den:homeManager.neovim#core";
    imports = [ inputs.nixvim.homeModules.nixvim ];

    programs.nixvim = {
      enable = true;
      imports = [ self.modules.nixvim.neovim ];
    };

    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    home.shellAliases = {
      v = "nvim";
      vi = "nvim";
      vim = "nvim";
      nv = "nvim";
    };
  };
}
