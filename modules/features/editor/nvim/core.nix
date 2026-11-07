{ inputs, ... }:
{
  flake.modules.nixvim.neovim =
    { config, ... }:
    {
      key = "den:nixvim.neovim#core";

      nixpkgs.source = inputs.nixpkgs.outPath;
      luaLoader.enable = true;
      plugins.lz-n.enable = true;

      withPython3 = false;
      withNodeJs = false;
      withRuby = false;

      globals = {
        mapleader = " ";
        maplocalleader = " ";
      };

      opts = {
        number = true;
        relativenumber = true;
        signcolumn = "yes";
        cursorline = true;
        colorcolumn = "80,120";
        scrolloff = 5;
        sidescrolloff = 5;

        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;
        breakindent = true;

        ignorecase = true;
        smartcase = true;
        inccommand = "split";

        splitbelow = true;
        splitright = true;

        undofile = true;
        updatetime = 250;
        timeoutlen = 300;
        termguicolors = true;

        foldlevel = 99;
      };

      diagnostic.settings = {
        severity_sort = true;
        virtual_text.spacing = 2;
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
          key = "<C-h>";
          action = "<C-w>h";
          options.desc = "Focus left window";
        }
        {
          mode = "n";
          key = "<C-j>";
          action = "<C-w>j";
          options.desc = "Focus lower window";
        }
        {
          mode = "n";
          key = "<C-k>";
          action = "<C-w>k";
          options.desc = "Focus upper window";
        }
        {
          mode = "n";
          key = "<C-l>";
          action = "<C-w>l";
          options.desc = "Focus right window";
        }
        {
          mode = [
            "n"
            "v"
          ];
          key = "<leader>y";
          action = ''"+y'';
          options.desc = "Yank to system clipboard";
        }
        {
          mode = [
            "n"
            "v"
          ];
          key = "<leader>p";
          action = ''"+p'';
          options.desc = "Paste from system clipboard";
        }
        {
          mode = "n";
          key = "<leader>q";
          action.__raw = "vim.diagnostic.setloclist";
          options.desc = "Diagnostics to location list";
        }
      ];

      autoGroups.den_yank_highlight.clear = true;
      autoCmd = [
        {
          event = "TextYankPost";
          group = "den_yank_highlight";
          callback.__raw = "function() vim.hl.on_yank() end";
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
          lua
          markdown
          markdown_inline
          nix
          query
          toml
          vim
          vimdoc
          yaml
        ];
      };
    };
}
