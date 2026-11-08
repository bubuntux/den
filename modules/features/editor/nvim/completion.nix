{
  flake.modules.nixvim.neovim = {
    key = "den:nixvim.neovim#completion";

    plugins.friendly-snippets.enable = true;

    plugins.blink-cmp = {
      enable = true;
      settings = {
        signature.enabled = true;
        completion.documentation.auto_show = true;
      };
    };
  };
}
