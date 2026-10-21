{ self, inputs, ... }:
{
  # Home Manager module for Claude Code
  flake.modules = {
    homeManager.claude-code =
      { pkgs, ... }:
      {
        key = "den:homeManager.claude-code";
        programs.claude-code = {
          enable = true;

          # Track claude-code from nixpkgs-unstable: it ships updates almost
          # daily and lags badly on the frozen stable channel. Setting the
          # package here (rather than a system overlay) keeps it with the feature
          # and applies wherever this home module is used, including the
          # standalone juliogm config. Everything else stays on stable.
          package =
            (import inputs.nixpkgs-unstable {
              inherit (pkgs.stdenv.hostPlatform) system;
              config.allowUnfree = true;
            }).claude-code;

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
        environment.systemPackages = [ pkgs.claude-code ];

        # Add home-manager claude-code module to shared modules
        home-manager.sharedModules = [ self.modules.homeManager.claude-code ];
      };
  };
}
