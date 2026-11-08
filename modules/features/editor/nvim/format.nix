{
  flake.modules.nixvim.neovim = {
    key = "den:nixvim.neovim#format";

    plugins.conform-nvim = {
      enable = true;
      autoInstall.enable = true;
      settings = {
        formatters_by_ft = {
          lua = [ "stylua" ];
          nix = [ "nixfmt" ];
        };
        default_format_opts.lsp_format = "fallback";
        format_on_save.__raw = ''
          function(bufnr)
            if not (vim.g.den_format_after_save or {})[vim.bo[bufnr].filetype] then
              return { timeout_ms = 500 }
            end
          end
        '';
        format_after_save.__raw = ''
          function(bufnr)
            if (vim.g.den_format_after_save or {})[vim.bo[bufnr].filetype] then
              return { timeout_ms = 20000 }
            end
          end
        '';
      };
    };

    keymaps = [
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>lf";
        action.__raw = "function() require('conform').format({ async = true }) end";
        options.desc = "Format buffer";
      }
    ];
  };
}
