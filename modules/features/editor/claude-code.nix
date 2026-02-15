{ self, ... }:
{
  # Home Manager module for Claude Code
  flake.homeModules.claude-code =
    { pkgs, ... }:
    let
      statusline = pkgs.writeShellScript "claude-statusline" ''
        input=$(${pkgs.coreutils}/bin/cat)

        MODEL=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.model.display_name // "Claude"')
        DIR=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.workspace.current_dir // "~"')
        PCT=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
        COST=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_cost_usd // 0')
        DURATION_MS=$(echo "$input" | ${pkgs.jq}/bin/jq -r '.cost.total_duration_ms // 0')

        # Project name from directory
        PROJECT="''${DIR##*/}"

        # Git info
        BRANCH=$(${pkgs.git}/bin/git -C "$DIR" branch --show-current 2>/dev/null)
        STAGED=$(${pkgs.git}/bin/git -C "$DIR" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(${pkgs.git}/bin/git -C "$DIR" diff --numstat 2>/dev/null | wc -l | tr -d ' ')

        GIT_INFO=""
        if [ -n "$BRANCH" ]; then
          GIT_INFO="$BRANCH"
          [ "$STAGED" -gt 0 ] 2>/dev/null && GIT_INFO="$GIT_INFO +$STAGED"
          [ "$MODIFIED" -gt 0 ] 2>/dev/null && GIT_INFO="$GIT_INFO ~$MODIFIED"
        fi

        # Context bar with color coding
        FILLED=$((PCT / 10))
        EMPTY=$((10 - FILLED))
        BAR=$(printf "%''${FILLED}s" | tr ' ' '#')$(printf "%''${EMPTY}s" | tr ' ' '-')

        if [ "$PCT" -ge 90 ]; then COLOR='\e[31m'
        elif [ "$PCT" -ge 70 ]; then COLOR='\e[33m'
        else COLOR='\e[32m'; fi
        RESET='\e[0m'

        # Format cost
        COST_FMT=$(printf '$%.2f' "$COST")

        # Format duration
        MINS=$((DURATION_MS / 60000))
        SECS=$(((DURATION_MS % 60000) / 1000))

        echo -e "[$MODEL] $PROJECT | $GIT_INFO | $COLOR[$BAR] $PCT%$RESET | $COST_FMT | ''${MINS}m ''${SECS}s"
      '';
    in
    {
      programs.claude-code = {
        enable = true;
        settings = {
          # Prefer the most advanced model
          model = "opus";

          # Status line with full dashboard
          statusLine = {
            type = "command";
            command = toString statusline;
          };

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
            deny = [
              # Environment and secret files
              "Read(.env)"
              "Read(.env.*)"
              "Edit(.env)"
              "Edit(.env.*)"
              "Read(secrets/**)"
              "Edit(secrets/**)"

              # SSH and GPG keys
              "Read(**/.ssh/**)"
              "Read(**/.gnupg/**)"

              # Private keys and certificates
              "Read(**/*.pem)"
              "Read(**/*.key)"
              "Read(**/*.p12)"
              "Read(**/*.pfx)"

              # Age/SOPS encrypted secrets (common in NixOS)
              "Read(**/*.age)"
              "Edit(**/*.age)"

              # Credential and token files
              "Read(**/.netrc)"
              "Read(**/.npmrc)"
              "Read(**/.docker/config.json)"
              "Read(**/.aws/**)"
              "Read(**/.kube/config)"

              # Destructive bash commands
              "Bash(rm *)"
              "Bash(rmdir *)"
              "Bash(chmod *)"
              "Bash(chown *)"
              "Bash(git push *)"
              "Bash(git reset --hard*)"
              "Bash(git checkout -- *)"
              "Bash(git clean *)"
              "Bash(nixos-rebuild *)"
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
