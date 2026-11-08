{
  flake.modules.nixvim.neovim = {
    key = "den:nixvim.neovim#git";

    plugins = {
      mini-diff = {
        enable = true;
        settings.view.style = "sign";
      };
      mini-git.enable = true;
      which-key.settings.spec = [
        {
          __unkeyed-1 = "<leader>g";
          group = "Git";
        }
      ];
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>go";
        action.__raw = "function() MiniDiff.toggle_overlay() end";
        options.desc = "Toggle diff overlay";
      }
      {
        mode = [
          "n"
          "x"
        ];
        key = "<leader>gs";
        action.__raw = "function() MiniGit.show_at_cursor() end";
        options.desc = "Show git info at cursor";
      }
    ];
  };
}
