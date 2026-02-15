{ self, ... }:
{
  # Home Manager module for Claude Code
  flake.homeModules.claude-code =
    { pkgs, ... }:
    {
      programs.claude-code = {
        enable = true;
        settings = {
          # Prefer the most advanced model
          model = "opus";

          # Allow non-destructive operations by default
          permissions = {
            defaultMode = "acceptEdits";
            allow = [
              # File reading and searching
              "Read"
              "Glob"
              "Grep"

              # Web tools
              "WebSearch"
              "WebFetch"

              # MCP servers
              "mcp__nixos__nix"
              "mcp__nixos__nix_versions"

              # Read-only git
              "Bash(git log *)"
              "Bash(git show *)"
              "Bash(git status *)"
              "Bash(git diff *)"
              "Bash(git branch *)"
              "Bash(git tag *)"
              "Bash(git remote *)"
              "Bash(git rev-parse *)"

              # Read-only filesystem
              "Bash(ls *)"
              "Bash(tree *)"
              "Bash(wc *)"
              "Bash(file *)"
              "Bash(stat *)"

              # Read-only nix
              "Bash(nix flake show *)"
              "Bash(nix flake metadata *)"
              "Bash(nix eval *)"
              "Bash(nix search *)"
              "Bash(nix --version)"
            ];
          };

          # Show turn duration for performance awareness
          showTurnDuration = true;
        };
      };
    };

  # NixOS module for Claude Code (installs package system-wide)
  flake.nixosModules.claude-code =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.claude-code ];

      # Add home-manager claude-code module to shared modules
      home-manager.sharedModules = [ self.homeModules.claude-code ];
    };
}
