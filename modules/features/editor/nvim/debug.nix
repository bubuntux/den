let
  mkDapKeymap = key: action: desc: {
    mode = "n";
    inherit key;
    action.__raw = "function() ${action} end";
    options.desc = desc;
  };
in
{
  flake.modules.nixvim.neovim =
    { config, lib, ... }:
    {
      key = "den:nixvim.neovim#debug";

      config = lib.mkIf config.plugins.dap.enable {
        plugins = {
          dap-view = {
            enable = true;
            settings.auto_toggle = true;
          };
          dap-virtual-text.enable = true;
          which-key.settings.spec = [
            {
              __unkeyed-1 = "<leader>d";
              group = "Debug";
            }
          ];
        };

        keymaps = [
          (mkDapKeymap "<leader>dc" "require('dap').continue()" "Continue")
          (mkDapKeymap "<leader>dR" "require('dap').restart()" "Restart")
          (mkDapKeymap "<leader>dq" "require('dap').terminate()" "Terminate")
          (mkDapKeymap "<leader>d." "require('dap').run_last()" "Re-run last debug session")
          (mkDapKeymap "<leader>dr" "require('dap').repl.toggle()" "Toggle REPL")
          (mkDapKeymap "<leader>dh" "require('dap.ui.widgets').hover()" "Hover")
          (mkDapKeymap "<leader>db" "require('dap').toggle_breakpoint()" "Toggle breakpoint")
          (mkDapKeymap "<leader>du" "require('dap-view').toggle()" "Toggle debug view")
          (mkDapKeymap "<leader>dgc" "require('dap').run_to_cursor()" "Continue to the cursor")
          (mkDapKeymap "<leader>dgi" "require('dap').step_into()" "Step into function")
          (mkDapKeymap "<leader>dgo" "require('dap').step_out()" "Step out of function")
          (mkDapKeymap "<leader>dgj" "require('dap').step_over()" "Next step")
          (mkDapKeymap "<leader>dgk" "require('dap').step_back()" "Step back")
          (mkDapKeymap "<leader>dvo" "require('dap').up()" "Go up stacktrace")
          (mkDapKeymap "<leader>dvi" "require('dap').down()" "Go down stacktrace")

          (mkDapKeymap "<F5>" "require('dap').continue()" "Continue")
          (mkDapKeymap "<S-F5>" "require('dap').terminate()" "Terminate")
          (mkDapKeymap "<F9>" "require('dap').toggle_breakpoint()" "Toggle breakpoint")
          (mkDapKeymap "<F10>" "require('dap').step_over()" "Step over")
          (mkDapKeymap "<F11>" "require('dap').step_into()" "Step into")
          (mkDapKeymap "<S-F11>" "require('dap').step_out()" "Step out")
        ];
      };
    };
}
