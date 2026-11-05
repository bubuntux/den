{ inputs, ... }: {
  flake-file.inputs.nvf.url = "github:NotAShelf/nvf";
  flake-file.inputs.nvf.inputs.nixpkgs.follows = "nixpkgs-unstable";

  flake.modules.homeManager.neovim =
    {
      pkgs,
      lib,
      ...
    }:
    {
      key = "den:homeManager.neovim";
      imports = [ inputs.nvf.homeManagerModules.default ];

      programs.nvf = {
        enable = true;
        defaultEditor = true;
        settings.vim = {
          package =
            inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.neovim-unwrapped;

          theme = {
            enable = true;
            name = "onedark";
          };

          globals = {
            mapleader = " ";
            maplocalleader = " ";
          };

          options = {
            scrolloff = 5;
            sidescrolloff = 5;
            number = true;
            relativenumber = true;
            cursorline = true;
            tabstop = 2;
            shiftwidth = 2;
            expandtab = true;
            ignorecase = true;
            smartcase = true;
            splitbelow = true;
            splitright = true;
          };

          mini = {
            indentscope.enable = true;
            statusline.enable = true;
            pairs.enable = true;
            files = {
              enable = true;
              setupOpts = {
                mappings = {
                  go_in = "<CR>";
                  go_in_plus = "<CR>";
                  go_out = "<BS>";
                  go_out_plus = "-";
                };
              };
            };
          };

          git = {
            enable = true;
            gitsigns.enable = true;
          };

          binds.whichKey.enable = true;

          lsp = {
            enable = true;
            inlayHints.enable = true;
            formatOnSave = true;
            mappings.format = null;
          };

          diagnostics.enable = true;

          autocomplete.blink-cmp.enable = true;
          fzf-lua.enable = true;

          languages = {
            enableTreesitter = true;
            enableFormat = true;
            rust.enable = true;
            nix = {
              enable = true;
              format.type = [ "nixfmt" ];
            };
            markdown = {
              enable = true;
              format.type = [ "mdformat" ];
              extensions.markview-nvim.enable = true;
            };
          };

          keymaps = [
            {
              mode = [ "n" ];
              key = "<leader>e";
              action = "<cmd>lua if not (package.loaded['mini.files'] and MiniFiles.close()) then MiniFiles.open(vim.api.nvim_buf_get_name(0), true) end<CR>";
              desc = "Toggle file tree";
            }
            {
              mode = [ "n" ];
              key = "<C-h>";
              action = "<C-w>h";
              desc = "Focus left window";
            }
            {
              mode = [ "n" ];
              key = "<C-l>";
              action = "<C-w>l";
              desc = "Focus right window";
            }
            {
              mode = [ "n" ];
              key = "<leader>f";
              action = "<cmd>FzfLua files<CR>";
              desc = "Find files";
            }
            {
              mode = [ "n" ];
              key = "<leader>b";
              action = "<cmd>FzfLua buffers<CR>";
              desc = "Open buffers";
            }
            {
              mode = [ "n" ];
              key = "<leader>/";
              action = "<cmd>FzfLua live_grep<CR>";
              desc = "Global search in project";
            }
            {
              mode = [ "n" ];
              key = "<leader>s";
              action = "<cmd>FzfLua lsp_document_symbols<CR>";
              desc = "Document symbols";
            }
            {
              mode = [ "n" ];
              key = "<leader>S";
              action = "<cmd>FzfLua lsp_workspace_symbols<CR>";
              desc = "Workspace symbols";
            }
            {
              mode = [ "n" ];
              key = "<leader>d";
              action = "<cmd>FzfLua diagnostics_document<CR>";
              desc = "Document diagnostics";
            }
            {
              mode = [ "n" ];
              key = "<leader>D";
              action = "<cmd>FzfLua diagnostics_workspace<CR>";
              desc = "Workspace diagnostics";
            }
            {
              mode = [ "n" ];
              key = "<leader>k";
              action = "<cmd>lua vim.lsp.buf.hover()<CR>";
              desc = "Show hover docs";
            }
            {
              mode = [ "n" ];
              key = "<leader>a";
              action = "<cmd>lua vim.lsp.buf.code_action()<CR>";
              desc = "Code action";
            }
            {
              mode = [ "n" ];
              key = "<leader>r";
              action = "<cmd>lua vim.lsp.buf.rename()<CR>";
              desc = "Rename symbol";
            }
            {
              mode = [
                "n"
                "v"
              ];
              key = "<leader>lf";
              action = "<cmd>lua require('conform').format({ lsp_format = 'fallback' })<CR>";
              desc = "Format buffer";
            }
            {
              mode = [
                "n"
                "v"
              ];
              key = "<leader>y";
              action = ''"+y'';
              desc = "Yank to system clipboard";
            }
            {
              mode = [
                "n"
                "v"
              ];
              key = "<leader>p";
              action = ''"+p'';
              desc = "Paste from system clipboard";
            }
          ];
        };
      };

      home.shellAliases = {
        v = "nvim";
        vi = "nvim";
        vim = "nvim";
        nv = "nvim";
      };
    };
}
