let
  mkGroup = key: group: {
    __unkeyed-1 = key;
    inherit group;
  };
in
{
  flake.modules.nixvim.neovim = {
    key = "den:nixvim.neovim#which-key";

    plugins.which-key = {
      enable = true;
      lazyLoad.settings.event = "DeferredUIEnter";
      settings.spec = [
        (mkGroup "<leader>l" "LSP")
        (mkGroup "<leader>lc" "Calls")
        (mkGroup "gr" "LSP")
        (mkGroup "s" "Surround")
        (mkGroup "[" "Prev")
        (mkGroup "]" "Next")
      ];
    };
  };
}
