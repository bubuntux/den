{
  flake.modules.nixvim.neovim = {
    key = "den:nixvim.neovim#lsp";

    plugins.lspconfig.enable = true;
    lsp.inlayHints.enable = true;
  };
}
