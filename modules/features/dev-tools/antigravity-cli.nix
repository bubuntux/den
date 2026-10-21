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
        notifications = true;
        showTips = true;
        showFeedbackSurvey = false;
        enableTelemetry = false;

        permissions = {
          allow = [
            "read_file(*)"
            "read_url(*)"

            "mcp(nixos/nix)"
            "mcp(nixos/nix_versions)"

            "command(grep)"
            "command(rg)"
            "command(sed -n)"

            "command(jj st)"
            "command(jj status)"
            "command(jj diff)"
            "command(jj log)"
            "command(jj show)"
            "command(jj evolog)"
            "command(jj op log)"
            "command(jj file list)"
            "command(jj bookmark list)"

            "command(git log)"
            "command(git show)"
            "command(git status)"
            "command(git diff)"
            "command(git branch)"
            "command(git tag)"
            "command(git remote)"
            "command(git rev-parse)"
            "command(git ls-files)"
            "command(git blame)"
            "command(git pull)"
            "command(git fetch)"

            "command(ls)"
            "command(tree)"
            "command(wc)"
            "command(file)"
            "command(stat)"

            "command(nix flake show)"
            "command(nix flake metadata)"
            "command(nix eval)"
            "command(nix search)"
            "command(nix path-info)"
            "command(nix --version)"
            "command(nix build)"
            "command(nix flake check)"
            "command(nix fmt)"

            "command(journalctl)"
            "command(systemctl status)"
            "command(systemctl list-units)"
            "command(systemctl --user status)"
            "command(systemctl --user list-units)"
          ];

          ask = [
            "command(git push)"
            "command(jj git push)"
            "command(gh pr create)"
            "command(gh pr merge)"

            "command(sudo nixos-rebuild)"
            "command(nix-collect-garbage)"
            "command(sudo nix-collect-garbage)"
          ];

          # Denying read_file also denies write_file on the same path.
          deny = [
            "read_file(**/.env)"
            "read_file(**/.env.*)"
            "read_file(**/secrets/**)"

            "read_file(~/.ssh/)"
            "read_file(~/.gnupg/)"
            "read_file(**/id_rsa*)"
            "read_file(**/id_ed25519*)"
            "read_file(**/id_ecdsa*)"

            "read_file(**/*.pem)"
            "read_file(**/*.key)"
            "read_file(**/*.p12)"
            "read_file(**/*.pfx)"
            "read_file(**/*.age)"
            "read_file(**/*.gpg)"
            "read_file(**/*.asc)"

            "read_file(~/.netrc)"
            "read_file(~/.npmrc)"
            "read_file(~/.docker/config.json)"
            "read_file(~/.aws/)"
            "read_file(~/.kube/config)"
            "read_file(~/.config/gh/hosts.yml)"
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
