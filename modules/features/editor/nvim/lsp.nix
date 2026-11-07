{
  flake.modules.nixvim.neovim =
    { pkgs, ... }:
    {
      key = "den:nixvim.neovim#lsp";

      plugins.lspconfig.enable = true;
      plugins.lazydev = {
        enable = true;
        lazyLoad.settings.ft = "lua";
      };

      lsp = {
        inlayHints.enable = true;

        keymaps = [
          {
            key = "gd";
            lspBufAction = "definition";
            options.desc = "Go to definition";
          }
          {
            key = "gD";
            lspBufAction = "declaration";
            options.desc = "Go to declaration";
          }
          {
            key = "gi";
            lspBufAction = "implementation";
            options.desc = "Go to implementation";
          }
          {
            key = "gy";
            lspBufAction = "type_definition";
            options.desc = "Go to type definition";
          }
          {
            key = "grr";
            lspBufAction = "references";
            options.desc = "List references";
          }
          {
            key = "K";
            lspBufAction = "hover";
            options.desc = "Show hover docs";
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "<leader>a";
            lspBufAction = "code_action";
            options.desc = "Code action";
          }
          {
            key = "<leader>r";
            lspBufAction = "rename";
            options.desc = "Rename symbol";
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "<leader>lf";
            action.__raw = "function() vim.lsp.buf.format({ async = true }) end";
            options.desc = "Format buffer";
          }
        ];

        servers = {
          nixd = {
            enable = true;
            config.settings.nixd.formatting.command = [ "nixfmt" ];
          };
          lua_ls = {
            enable = true;
            config.settings.Lua.diagnostics.globals = [ "vim" ];
          };
        };
      };

      extraPackages = with pkgs; [
        nixfmt
        stylua
      ];
    };
}
