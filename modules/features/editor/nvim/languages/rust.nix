{
  flake.modules.homeManager.neovim =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      key = "den:homeManager.neovim#rust";

      options.den.neovim.languages.rust = lib.mkEnableOption "Rust language support";

      config.den.neovim.languages.toml = lib.mkIf config.den.neovim.languages.rust (lib.mkDefault true);

      config.programs.nixvim = lib.mkIf config.den.neovim.languages.rust {
        plugins.treesitter.grammarPackages =
          with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
            rust
          ];
        lsp.servers.rust_analyzer.enable = true;

        plugins.dap.enable = true;
        plugins.dap-lldb = {
          enable = true;
          settings.codelldb_path = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
        };
      };
    };
}
