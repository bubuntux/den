{ self, inputs, ... }:
{
  # Home Manager module for Claude Code
  flake.homeModules.claude-code =
    { pkgs, ... }:
    {
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

        settings = import ./_claude-settings.nix { inherit pkgs; };

        # Global CLAUDE.md — applies to all projects
        context = ''
          # Global Instructions

          ## Style
          - Concise and direct; plain language; no filler
          - Emojis are fine but not preferred; use sparingly
          - Prefer Markdown when presenting or writing down information
          - Reference code as `file_path:line_number`

          ## Version Control (jj)
          - Use jj, not git, for version control (`jj st`, `jj diff`, `jj describe`)
          - Show the diff and proposed change description before you commit

          ## Principles
          - Simplicity first: minimal, targeted changes; root causes over patches
          - Verify before done: prove it works (tests, logs, real output)
          - Scope discipline: note unrelated issues, don't fix them
        '';

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
