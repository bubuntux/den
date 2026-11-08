{
  flake.modules.homeManager.neovim =
    { config, lib, ... }:
    {
      key = "den:homeManager.neovim#markdown";

      options.den.neovim.languages.markdown = lib.mkEnableOption "Markdown language support";

      config.programs.nixvim = lib.mkIf config.den.neovim.languages.markdown {
        plugins.render-markdown = {
          enable = true;
          settings.completions.lsp.enabled = true;
        };
        plugins.conform-nvim.settings.formatters_by_ft.markdown = [ "rumdl" ];
        lsp.servers = {
          marksman.enable = true;
          rumdl.enable = true;
        };
      };
    };
}
