let
  mkHipatternsHighlighter = group: words: {
    pattern = map (word: "%f[%w_]()${word}%f[^%w_].-()%s*$") words;
    inherit group;
  };
in
{
  flake.modules.nixvim.neovim = {
    key = "den:nixvim.neovim#mini";

    globals = {
      loaded_netrw = 1;
      loaded_netrwPlugin = 1;
    };

    autoCmd = [
      {
        event = "VimEnter";
        callback.__raw = ''
          function()
            local buf = vim.api.nvim_get_current_buf()
            local bufname = vim.api.nvim_buf_get_name(buf)
            if bufname ~= "" and vim.fn.isdirectory(bufname) == 1 then
              vim.api.nvim_buf_delete(buf, { force = true })
              require("lz.n").trigger_load("mini.files")
              vim.schedule(function()
                MiniFiles.open(bufname, false)
              end)
            end
          end
        '';
      }
    ];

    plugins = {
      mini-basics = {
        enable = true;
        settings.mappings.windows = true;
      };
      mini-notify.enable = true;
      mini-bracketed = {
        enable = true;
        lazyLoad.settings.event = "DeferredUIEnter";
      };

      mini-ai = {
        enable = true;
        lazyLoad.settings.event = "DeferredUIEnter";
      };
      mini-surround = {
        enable = true;
        lazyLoad.settings.event = "DeferredUIEnter";
      };
      mini-splitjoin = {
        enable = true;
        lazyLoad.settings.event = "DeferredUIEnter";
      };
      mini-pairs = {
        enable = true;
        lazyLoad.settings.event = "InsertEnter";
      };

      mini-icons.enable = true;
      mini-statusline.enable = true;
      mini-indentscope.enable = true;
      mini-trailspace.enable = true;

      mini-hipatterns = {
        enable = true;
        settings.highlighters = {
          fixme = mkHipatternsHighlighter "MiniHipatternsFixme" [
            "FIXME"
            "ISSUE"
            "BUG"
          ];
          hack = mkHipatternsHighlighter "MiniHipatternsHack" [
            "HACK"
            "WARN"
            "WARNING"
          ];
          todo = mkHipatternsHighlighter "MiniHipatternsTodo" [
            "TODO"
            "PERF"
          ];
          note = mkHipatternsHighlighter "MiniHipatternsNote" [
            "NOTE"
            "INFO"
          ];
          hex_color.__raw = "require('mini.hipatterns').gen_highlighter.hex_color()";
        };
      };

      mini-files = {
        enable = true;
        settings.mappings = {
          go_in = "<CR>";
          go_in_plus = "<CR>";
          go_out = "<BS>";
          go_out_plus = "-";
        };
        lazyLoad.settings.keys = [
          {
            __unkeyed-1 = "<leader>e";
            __unkeyed-2.__raw = ''
              function()
                if not MiniFiles.close() then
                  MiniFiles.open(vim.api.nvim_buf_get_name(0), true)
                end
              end
            '';
            desc = "Toggle file tree";
          }
        ];
      };
    };
  };
}
