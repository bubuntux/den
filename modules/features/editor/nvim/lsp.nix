{
  flake.modules.nixvim.neovim = {
    key = "den:nixvim.neovim#lsp";

    plugins.lspconfig.enable = true;
    plugins.lazydev = {
      enable = true;
      lazyLoad.settings.ft = "lua";
    };

    lsp = {
      inlayHints.enable = true;

      servers = {
        nixd.enable = true;
        lua_ls.enable = true;
      };
    };
  };
}
