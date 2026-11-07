let
  mkFzfKeymap = key: command: desc: {
    mode = "n";
    inherit key;
    action = "<cmd>FzfLua ${command}<CR>";
    options.desc = desc;
  };
in
{
  flake.modules.nixvim.neovim = {
    key = "den:nixvim.neovim#fzf-lua";

    plugins.fzf-lua = {
      enable = true;
      lazyLoad.settings.cmd = "FzfLua";
    };

    keymaps = [
      (mkFzfKeymap "<leader>f" "files" "Find files")
      (mkFzfKeymap "<leader>b" "buffers" "Open buffers")
      (mkFzfKeymap "<leader>/" "live_grep" "Global search in project")
      (mkFzfKeymap "<leader>o" "oldfiles" "Recent files")
      (mkFzfKeymap "<leader>R" "resume" "Resume last search")
      (mkFzfKeymap "<leader>j" "jumps" "Jumplist")
      (mkFzfKeymap "<leader>s" "lsp_document_symbols" "Document symbols")
      (mkFzfKeymap "<leader>S" "lsp_workspace_symbols" "Workspace symbols")
      (mkFzfKeymap "<leader>d" "diagnostics_document" "Document diagnostics")
      (mkFzfKeymap "<leader>D" "diagnostics_workspace" "Workspace diagnostics")
      (mkFzfKeymap "<leader>lci" "lsp_incoming_calls" "Incoming calls")
      (mkFzfKeymap "<leader>lco" "lsp_outgoing_calls" "Outgoing calls")
    ];

    # fzf-lua is lazy, so each override loads it on first use rather than at startup.
    extraConfigLua = ''
      local function fzf_lua()
        require("lz.n").trigger_load("fzf-lua")
        return require("fzf-lua")
      end

      local function fzf_picker(picker, defaults)
        return function(opts)
          fzf_lua()[picker](vim.tbl_extend("keep", opts or {}, defaults or {}))
        end
      end

      vim.lsp.buf.references = fzf_picker("lsp_references")
      vim.lsp.buf.implementation = fzf_picker("lsp_implementations")
      vim.lsp.buf.definition = fzf_picker("lsp_definitions", { jump1 = true })
      vim.lsp.buf.type_definition = fzf_picker("lsp_typedefs", { jump1 = true })
      vim.lsp.buf.declaration = fzf_picker("lsp_declarations", { jump1 = true })

      vim.ui.select = function(...)
        fzf_lua().register_ui_select()
        return vim.ui.select(...)
      end
    '';
  };
}
