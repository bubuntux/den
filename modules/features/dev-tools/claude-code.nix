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

          ## Principles
          - Simplicity first: minimal, targeted changes; root causes over patches
          - Verify before done: prove it works (tests, logs, real output)
          - Scope discipline: note unrelated issues, don't fix them

          ## Code Quality
          - Readability first: code should read clearly; match the surrounding style, naming, and idioms
          - Be nit-picky about names: variables, functions, and types should say what they are; no vague or abbreviated names
          - Placement matters: put functions, methods, and definitions where a reader would expect them; keep related code together
          - Review correctness: check edge cases, error paths, and assumptions before calling it done
          - Watch for side effects: trace what else a change touches; flag any state, I/O, or ordering effects
          - Don't break existing flows: preserve current behavior and interfaces unless the change explicitly requires otherwise

          ## Version Control (jj)
          - Always prefer jj over git; use jj for every version-control operation (`jj st`, `jj diff`, `jj commit`)
          - Show the diff and proposed change description before you commit
          - When I say "commit", run `jj commit` (the commit command that finalizes the change) — NOT `jj describe`, which only sets the message
          - Commit only — NEVER push. "Commit" never implies push: after `jj commit`, stop. Do not run `jj git push` (or `git push`), move bookmarks to remotes, or open/merge PRs unless I explicitly say "push"

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
