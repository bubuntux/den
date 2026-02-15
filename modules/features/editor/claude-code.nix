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
