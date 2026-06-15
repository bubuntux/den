{ inputs, ... }:
{
  # nvf — declarative Neovim. The input is declared inline; regenerate
  # flake.nix afterwards with `nix run .#write-flake`.
  flake-file.inputs.nvf = {
    url = "github:notashelf/nvf";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.homeModules.neovim =
    { ... }:
    {
      # Wrap with an explicit key so nvf's (attrset) module deduplicates when
      # this feature is reached through multiple NixOS import paths (e.g. katara).
      imports = [
        {
          key = "homeModules.nvf";
          imports = [ inputs.nvf.homeManagerModules.default ];
        }
      ];

      # Mirrors the upstream `nix run github:notashelf/nvf` default config
      # (configuration.nix, isMaximal = false). Tweak from here.
      programs.nvf = {
        enable = true;
        settings.vim = {
          viAlias = true;
          vimAlias = true;

          debugMode = {
            enable = false;
            level = 16;
            logFile = "/tmp/nvim.log";
          };

          opts.expandtab = true;

          spellcheck.enable = true;

          lsp = {
            enable = true;
            formatOnSave = true;
            lightbulb.enable = true;
            trouble.enable = true;
            lspSignature.enable = true;
          };

          debugger.nvim-dap = {
            enable = true;
            ui.enable = true;
          };

          languages = {
            enableTreesitter = true;
            enableFormat = true;
            enableExtraDiagnostics = true;
            nix.enable = true;
            markdown.enable = true;
          };

          # Theme: onedark (matching helix.nix).
          theme = {
            enable = true;
            name = "onedark";
            style = "dark";
          };
          statusline.lualine = {
            enable = true;
            theme = "onedark";
          };

          visuals = {
            nvim-web-devicons.enable = true;
            nvim-cursorline.enable = true;
            cinnamon-nvim.enable = true;
            fidget-nvim.enable = true;
            highlight-undo.enable = true;
            indent-blankline.enable = true;
            blink-indent.enable = true;
          };

          autopairs.nvim-autopairs.enable = true;
          autocomplete.nvim-cmp.enable = true;
          snippets.luasnip.enable = true;

          filetree.neo-tree.enable = true;
          tabline.nvimBufferline.enable = true;
          treesitter.context.enable = true;
          binds = {
            whichKey.enable = true;
            cheatsheet.enable = true;
          };
          telescope.enable = true;

          git = {
            enable = true;
            gitsigns.enable = true;
          };

          notify.nvim-notify.enable = true;
          utility = {
            diffview-nvim.enable = true;
            motion = {
              hop.enable = true;
              leap.enable = true;
            };
          };
          notes.todo-comments.enable = true;

          terminal.toggleterm = {
            enable = true;
            lazygit.enable = true;
          };

          ui = {
            borders.enable = true;
            noice.enable = true;
            colorizer.enable = true;
            illuminate.enable = true;
            smartcolumn.enable = true;
            fastaction.enable = true;
          };

          comments.comment-nvim.enable = true;
        };
      };
    };
}
