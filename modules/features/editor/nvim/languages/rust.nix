{
  flake.modules.homeManager.neovim =
    { config, lib, ... }:
    {
      key = "den:homeManager.neovim#rust";

      options.den.neovim.languages.rust = lib.mkEnableOption "Rust language support";

      config.programs.nixvim = lib.mkIf config.den.neovim.languages.rust {
        plugins.treesitter.grammarPackages =
          with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
            rust
          ];
        lsp.servers.rust_analyzer.enable = true;
      };
    };
}
