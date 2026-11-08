{
  flake.modules.homeManager.neovim =
    { config, lib, ... }:
    {
      key = "den:homeManager.neovim#nix";

      options.den.neovim.languages.nix = lib.mkEnableOption "Nix language support";

      config.programs.nixvim = lib.mkIf config.den.neovim.languages.nix {
        plugins.treesitter.grammarPackages =
          with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
            nix
          ];
        plugins.conform-nvim.settings.formatters_by_ft.nix = [ "nixfmt" ];
        lsp.servers.nixd.enable = true;
      };
    };
}
