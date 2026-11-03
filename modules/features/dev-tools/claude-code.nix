{ self, inputs, ... }:
{
  flake-file.inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  # Home Manager module for Claude Code
  flake.modules = {
    homeManager.claude-code =
      { pkgs, ... }:
      {
        key = "den:homeManager.claude-code";
        programs.claude-code = {
          enable = true;

          package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;

          settings = import ./_claude-settings.nix { };

          # Global CLAUDE.md — applies to all projects
          context = ./_global-instructions.md;

        };
      };

    # NixOS module for Claude Code (installs package system-wide)
    nixos.claude-code =
      { pkgs, ... }:
      {
        key = "den:nixos.claude-code";
        environment.systemPackages = [
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
        ];

        # Add home-manager claude-code module to shared modules
        home-manager.sharedModules = [ self.modules.homeManager.claude-code ];
      };
  };
}
