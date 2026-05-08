{ pkgs }:
let
  claudeModel = "opus[1m]";
  statusline = pkgs.writeShellScript "claude-statusline" ''
    # Single jq call to extract raw fields; formatting happens in shell.
    # Use US (\x1f) as the separator — tab is whitespace and bash's `read`
    # would collapse consecutive tabs, shifting fields when one is empty.
    IFS=$'\x1f' read -r MODEL EFFORT DIR PCT COST_USD WALL_MS API_MS LINES_ADD LINES_DEL < <(
      ${pkgs.jq}/bin/jq -j '
        [
          .model.display_name // "Claude",
          .effort.level // "",
          .workspace.current_dir // "~",
          (.context_window.used_percentage // 0 | floor),
          (.cost.total_cost_usd // 0),
          (.cost.total_duration_ms // 0),
          (.cost.total_api_duration_ms // 0),
          (.cost.total_lines_added // 0),
          (.cost.total_lines_removed // 0)
        ] | map(tostring) | join("")'
    )

    PROJECT=$(basename "$DIR")

    # Git branch (only if in a git repo)
    BRANCH=$(${pkgs.git}/bin/git -C "$DIR" branch --show-current 2>/dev/null)

    # Context bar with color coding
    FILLED=$((PCT / 10))
    EMPTY=$((10 - FILLED))
    BAR=$(printf "%*s" "$FILLED" "" | tr ' ' '#')$(printf "%*s" "$EMPTY" "" | tr ' ' '-')

    if [ "$PCT" -ge 90 ]; then COLOR='\e[31m'
    elif [ "$PCT" -ge 70 ]; then COLOR='\e[33m'
    else COLOR='\e[32m'; fi
    RESET='\e[0m'

    # Cost: always 2 decimals; suppress only when truly zero
    COST=$(printf '$%.2f' "$COST_USD")
    [ "$COST" = '$0.00' ] && COST=""

    # Duration formatter: ms → "Hh Mm Ss" / "Mm Ss" / "Ss" / ""
    fmt_duration() {
      local s=$(( $1 / 1000 ))
      if [ "$s" -ge 3600 ]; then
        printf '%dh %dm %ds' $((s/3600)) $((s%3600/60)) $((s%60))
      elif [ "$s" -ge 60 ]; then
        printf '%dm %ds' $((s/60)) $((s%60))
      elif [ "$s" -gt 0 ]; then
        printf '%ds' "$s"
      fi
    }
    WALL=$(fmt_duration "$WALL_MS")
    API=$(fmt_duration "$API_MS")

    # Code churn (only when non-zero)
    LINES=""
    if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]; then
      LINES="+$LINES_ADD/-$LINES_DEL"
    fi

    # Build output with conditional sections
    TAG="$MODEL"
    [ -n "$EFFORT" ] && TAG="$TAG/$EFFORT"
    OUT="[$TAG] $PROJECT"
    [ -n "$BRANCH" ] && OUT="$OUT | $BRANCH"
    OUT="$OUT | $COLOR[$BAR] $PCT%$RESET"
    [ -n "$LINES" ] && OUT="$OUT | $LINES"
    [ -n "$COST" ] && OUT="$OUT | $COST"
    if [ -n "$WALL" ] && [ -n "$API" ]; then
      OUT="$OUT | $WALL (api $API)"
    elif [ -n "$WALL" ]; then
      OUT="$OUT | $WALL"
    fi

    echo -e "$OUT"
  '';

in
{
  # Prefer the most advanced model
  model = claudeModel;
  effortLevel = "xhigh";

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
