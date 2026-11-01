{ inputs, ... }:
{
  flake.modules.homeManager.antigravity-cli =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      settingsFile = (pkgs.formats.json { }).generate "antigravity-cli-settings.json" {
        agentMode = "auto";
        notifications = true;
        showTips = true;
        showFeedbackSurvey = false;
        enableTelemetry = false;

        permissions = {
          # Denying read_file also denies write_file on the same path.
          # Absolute literal paths only: the terminal sandbox rejects globs
          # ("globs not supported") and `~` ("non-absolute file path"), and
          # then refuses to run any command.
          deny =
            map (path: "read_file(${config.home.homeDirectory}/${path})") [
              ".ssh/"
              ".gnupg/"

              ".netrc"
              ".npmrc"
              ".docker/config.json"
              ".aws/"
              ".kube/config"
              ".claude/.credentials.json"

              # Keyrings and certificate stores
              ".local/share/keyrings/"
              ".pki/"

              # Browser profiles (cookies, saved logins)
              ".mozilla/"
              ".config/google-chrome/"
              ".config/chromium/"
            ]
            ++ [
              # sops-nix decrypted secrets
              "read_file(/run/secrets/)"
            ];
        };
      };
    in
    {
      key = "den:homeManager.antigravity-cli";
      programs.antigravity-cli = {
        enable = true;

        # Unstable-only; the stable channel has no antigravity-cli package.
        package =
          (import inputs.nixpkgs-unstable {
            inherit (pkgs.stdenv.hostPlatform) system;
            config.allowUnfree = true;
          }).antigravity-cli;

        context.GEMINI = ./_global-instructions.md;

        inherit (config.programs.claude-code) skills;

        mcpServers.nixos = {
          command = "nix";
          args = [
            "run"
            "github:utensils/mcp-nixos"
            "--"
          ];
        };
      };

      # The CLI writes to its own settings.json (trustedWorkspaces), so it stays
      # a mutable file rather than a store symlink. jq's `*` favours its right
      # operand, so the Nix base goes last and wins on every key it sets; `*`
      # replaces arrays, so Nix owns the permission lists outright.
      home.activation.antigravityCliSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        target="$HOME/.gemini/antigravity-cli/settings.json"
        mkdir -p "$(dirname "$target")"
        if [ -f "$target" ] && [ ! -L "$target" ]; then
          ${pkgs.jq}/bin/jq -s '.[1] * .[0]' \
            "${settingsFile}" "$target" \
            > "$target.tmp"
          mv "$target.tmp" "$target"
        else
          rm -f "$target"
          cp "${settingsFile}" "$target"
          chmod 644 "$target"
        fi
      '';
    };
}
