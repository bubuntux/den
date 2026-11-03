{inputs, ...}: {
  flake-file.inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  flake.modules.homeManager.antigravity-cli = {
    config,
    pkgs,
    lib,
    ...
  }: let
    settingsFile = (pkgs.formats.json {}).generate "antigravity-cli-settings.json" {
      agentMode = "auto";
      notifications = true;
      showTips = true;
      showFeedbackSurvey = false;
      enableTelemetry = false;

      permissions = {
        allow = [
          "read_file(/nix/store/)"
          "read_file(${config.home.homeDirectory}/.cargo/)"

          # Let `gh` read its config and reach GitHub inside the sandbox, and
          # auto-approve direct `gh` commands if run outside the sandbox.
          "read_file(${config.home.homeDirectory}/.config/gh/)"
          "read_url(https://api.github.com)"
          "read_url(https://github.com)"
          "command(gh)"

          # Match `mcpServers.nixos` configured below.
          "mcp(nixos/nix)"
          "mcp(nixos/nix_versions)"
        ];

        # Hard checkpoints (`deny > ask > allow`): force a prompt even in
        # `auto` mode, and override `command(gh)` above for PR/repo mutations.
        ask = [
          "command(git push)"
          "command(jj git push)"
          "command(gh pr create)"
          "command(gh pr merge)"
          "command(gh repo delete)"

          "command(sudo nixos-rebuild)"
          "command(nix-collect-garbage)"
          "command(sudo nix-collect-garbage)"
        ];

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
  in {
    key = "den:homeManager.antigravity-cli";
    programs.antigravity-cli = {
      enable = true;

      package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.antigravity-cli;

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
    # a mutable file rather than a store symlink. Overlay Nix keys onto the
    # existing file while replacing `.permissions` wholesale so removed lists
    # or rules never linger from previous activations.
    home.activation.antigravityCliSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      target="$HOME/.gemini/antigravity-cli/settings.json"
      mkdir -p "$(dirname "$target")"
      if [ -f "$target" ] && [ ! -L "$target" ]; then
        ${pkgs.jq}/bin/jq -s \
          '.[0] as $nix | (.[1] | del(.mode)) * $nix | .permissions = $nix.permissions' \
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
