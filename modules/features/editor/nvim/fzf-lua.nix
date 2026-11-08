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
      (mkFzfKeymap "<leader>S" "lsp_workspace_symbols" "Workspace symbols")
      (mkFzfKeymap "<leader>d" "diagnostics_document" "Document diagnostics")
      (mkFzfKeymap "<leader>D" "diagnostics_workspace" "Workspace diagnostics")
      (mkFzfKeymap "<leader>lci" "lsp_incoming_calls" "Incoming calls")
      (mkFzfKeymap "<leader>lco" "lsp_outgoing_calls" "Outgoing calls")
    ];

    # Buffer-local, so these take the built-in LSP keys over in LSP buffers only.
    lsp.keymaps = [
      (mkFzfKeymap "gd" "lsp_definitions" "Go to definition")
      (mkFzfKeymap "gD" "lsp_declarations" "Go to declaration")
      (mkFzfKeymap "grr" "lsp_references" "List references")
      (mkFzfKeymap "gri" "lsp_implementations" "Go to implementation")
      (mkFzfKeymap "grt" "lsp_typedefs" "Go to type definition")
      (mkFzfKeymap "gO" "lsp_document_symbols" "Document symbols")
    ];

    extraConfigLua = ''
      vim.ui.select = function(...)
        require("lz.n").trigger_load("fzf-lua")
        require("fzf-lua").register_ui_select()
        return vim.ui.select(...)
      end
    '';
  };
}
