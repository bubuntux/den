{ pkgs }:
let
  claudeModel = "opus[1m]";
  statusline = pkgs.writeShellScript "claude-statusline" ''
    # Single jq call to extract and format all fields
    IFS=$'\t' read -r MODEL PROJECT DIR PCT COST DURATION < <(
      ${pkgs.jq}/bin/jq -r '
        (.cost.total_duration_ms // 0 | . / 1000 | floor) as $secs |
        [
          .model.display_name // "Claude",
          (.workspace.current_dir // "~" | split("/") | last),
          .workspace.current_dir // "~",
          (.context_window.used_percentage // 0 | floor),
          (.cost.total_cost_usd // 0 | if . > 0 then "$\(. * 100 | round | . / 100)" else "" end),
          (if $secs >= 3600 then "\($secs / 3600 | floor)h \($secs % 3600 / 60 | floor)m \($secs % 60)s"
           elif $secs > 0 then "\($secs / 60 | floor)m \($secs % 60)s"
           else "" end)
        ] | @tsv'
    )

    # Git branch (only if in a git repo)
    BRANCH=$(${pkgs.git}/bin/git -C "$DIR" branch --show-current 2>/dev/null)

    # Context bar with color coding
    FILLED=$((PCT / 10))
    EMPTY=$((10 - FILLED))
    BAR=$(printf "%''${FILLED}s" | tr ' ' '#')$(printf "%''${EMPTY}s" | tr ' ' '-')

    if [ "$PCT" -ge 90 ]; then COLOR='\e[31m'
    elif [ "$PCT" -ge 70 ]; then COLOR='\e[33m'
    else COLOR='\e[32m'; fi
    RESET='\e[0m'

    # Build output with conditional sections
    OUT="[$MODEL] $PROJECT"
    [ -n "$BRANCH" ] && OUT="$OUT | $BRANCH"
    OUT="$OUT | $COLOR[$BAR] $PCT%$RESET"
    [ -n "$COST" ] && OUT="$OUT | $COST"
    [ -n "$DURATION" ] && OUT="$OUT | $DURATION"

    echo -e "$OUT"
  '';

in
{
  # Prefer the most advanced model
  model = claudeModel;
  effortLevel = "high";

  # Use the full 1M context window before auto-compact kicks in
  autoCompactWindow = 1000000;

  # Snapshot files before edits so /rewind can restore them
  fileCheckpointingEnabled = true;

  # Flicker-free renderer with virtualized scrollback
  tui = "fullscreen";

  # Background memory consolidation across sessions
  autoDreamEnabled = true;

  # Surface thinking summaries in the transcript view
  showThinkingSummaries = true;

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

      # Read-only git (canonical `<cmd>:*` prefix syntax)
      "Bash(git log:*)"
      "Bash(git show:*)"
      "Bash(git status:*)"
      "Bash(git diff:*)"
      "Bash(git branch:*)"
      "Bash(git tag:*)"
      "Bash(git remote:*)"
      "Bash(git rev-parse:*)"
      "Bash(git ls-files:*)"
      "Bash(git blame:*)"

      # Read-only filesystem
      "Bash(ls:*)"
      "Bash(tree:*)"
      "Bash(wc:*)"
      "Bash(file:*)"
      "Bash(stat:*)"

      # Read-only nix
      "Bash(nix flake show:*)"
      "Bash(nix flake metadata:*)"
      "Bash(nix eval:*)"
      "Bash(nix search:*)"
      "Bash(nix --version)"
    ];
    deny = [
      # Environment and secret files (recursive)
      "Read(**/.env)"
      "Read(**/.env.*)"
      "Edit(**/.env)"
      "Edit(**/.env.*)"
      "Read(**/secrets/**)"
      "Edit(**/secrets/**)"

      # SSH and GPG dirs
      "Read(**/.ssh/**)"
      "Edit(**/.ssh/**)"
      "Read(**/.gnupg/**)"
      "Edit(**/.gnupg/**)"

      # SSH private keys outside ~/.ssh (defense-in-depth)
      "Read(**/id_rsa*)"
      "Read(**/id_ed25519*)"
      "Read(**/id_ecdsa*)"

      # Private keys and certificates
      "Read(**/*.pem)"
      "Edit(**/*.pem)"
      "Read(**/*.key)"
      "Edit(**/*.key)"
      "Read(**/*.p12)"
      "Edit(**/*.p12)"
      "Read(**/*.pfx)"
      "Edit(**/*.pfx)"

      # Age/SOPS encrypted secrets (common in NixOS)
      "Read(**/*.age)"
      "Edit(**/*.age)"

      # GPG-encrypted / signed blobs
      "Read(**/*.gpg)"
      "Read(**/*.asc)"

      # Credential and token files
      "Read(**/.netrc)"
      "Edit(**/.netrc)"
      "Read(**/.npmrc)"
      "Edit(**/.npmrc)"
      "Read(**/.docker/config.json)"
      "Edit(**/.docker/config.json)"
      "Read(**/.aws/**)"
      "Edit(**/.aws/**)"
      "Read(**/.kube/config)"
      "Edit(**/.kube/config)"
      "Read(**/.config/gh/hosts.yml)"
    ];
  };

  # Auto-approve MCP servers from project .mcp.json
  enableAllProjectMcpServers = true;

  # Auto-delete inactive sessions after 90 days
  cleanupPeriodDays = 90;

  # Show progress bar for long operations
  terminalProgressBarEnabled = true;

  # Show turn duration for performance awareness
  showTurnDuration = true;

  # Force subagents to use the same model as the main thread
  env.CLAUDE_CODE_SUBAGENT_MODEL = claudeModel;

  # Always show extended thinking for visibility into reasoning
  alwaysThinkingEnabled = true;
}
