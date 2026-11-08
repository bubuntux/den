{
  flake.modules.homeManager.neovim =
    { config, lib, ... }:
    {
      key = "den:homeManager.neovim#toml";

      options.den.neovim.languages.toml = lib.mkEnableOption "TOML language support";

      config.programs.nixvim = lib.mkIf config.den.neovim.languages.toml {
        plugins.treesitter.grammarPackages =
          with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
            toml
          ];
        plugins.conform-nvim.settings.formatters_by_ft.toml = [ "taplo" ];
        lsp.servers.taplo.enable = true;
      };
    };
}
