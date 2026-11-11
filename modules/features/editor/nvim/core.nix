{ inputs, ... }:
{
  flake.modules.nixvim.neovim =
    { config, pkgs, ... }:
    {
      key = "den:nixvim.neovim#core";

      nixpkgs.source = inputs.nixpkgs.outPath;
      luaLoader.enable = true;
      plugins.lz-n.enable = true;

      withPython3 = false;
      withNodeJs = false;
      withRuby = false;

      clipboard = {
        register = "unnamedplus";
        providers.wl-copy.enable = pkgs.stdenv.hostPlatform.isLinux;
      };

      extraConfigLua = ''
        if vim.env.SSH_TTY or vim.env.SSH_CONNECTION or not vim.env.WAYLAND_DISPLAY then
          vim.g.clipboard = {
            name = "OSC 52",
            copy = {
              ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
              ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
            },
            paste = {
              ["+"] = function()
                return vim.split(vim.fn.getreg('"'), "\n")
              end,
              ["*"] = function()
                return vim.split(vim.fn.getreg('"'), "\n")
              end,
            },
          }
        end
      '';

      globals = {
        mapleader = " ";
        maplocalleader = " ";
      };

      opts = {
        relativenumber = true;
        colorcolumn = "80,120";
        scrolloff = 5;
        sidescrolloff = 5;

        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;

        inccommand = "split";
        updatetime = 250;
        timeoutlen = 300;
        foldlevel = 99;
      };

      diagnostic.settings = {
        severity_sort = true;
        virtual_text.spacing = 2;
        virtual_lines.current_line = true;
        float = {
          border = "rounded";
          source = "if_many";
        };
      };

      keymaps = [
        {
          mode = "n";
          key = "<Esc>";
          action = "<cmd>nohlsearch<CR>";
          options.desc = "Clear search highlight";
        }
        {
          mode = "n";
          key = "<leader>q";
          action.__raw = "vim.diagnostic.setloclist";
          options.desc = "Diagnostics to location list";
        }
      ];

      colorschemes.onedark = {
        enable = true;
        settings.style = "dark";
      };
      highlightOverride."@lsp.type.modifier".link = "@keyword";

      plugins.treesitter = {
        enable = true;
        highlight.enable = true;
        folding.enable = true;
        grammarPackages = with config.plugins.treesitter.package.builtGrammars; [
          bash
          json
          markdown
          markdown_inline
          query
          vim
          vimdoc
          yaml
        ];
      };
    };
}
