_:
let
  claudeModel = "opus[1m]";
in
{
  # Prefer the most advanced model
  model = claudeModel;
  effortLevel = "xhigh";

  # Snapshot files before edits so /rewind can restore them
  fileCheckpointingEnabled = true;

  # Flicker-free renderer with virtualized scrollback
  tui = "fullscreen";

  # Surface thinking summaries in the transcript view
  showThinkingSummaries = true;

  # `auto` sends anything that is not a read or a working-dir edit to a
  # classifier instead of prompting; the `allow` list below just skips that
  # round-trip for the commands this repo uses most.
  #
  # Only honoured from ~/.claude/settings.json (a checked-out repo cannot grant
  # itself auto mode), and needs a recent model -- otherwise it falls back to
  # `default`, which prompts more than `acceptEdits` did.
  permissions = {
    defaultMode = "auto";
    allow = [
      # File reading and searching
      "Read"
      "Glob"
      "Grep"
      "Bash(grep:*)"
      "Bash(rg:*)"
      "Bash(sed -n:*)"

      # Web tools
      "WebSearch"
      "WebFetch"

      # MCP servers
      "mcp__nixos__nix"
      "mcp__nixos__nix_versions"

      # Read-only jj (the preferred VCS; see the global context below)
      "Bash(jj st:*)"
      "Bash(jj status:*)"
      "Bash(jj diff:*)"
      "Bash(jj log:*)"
      "Bash(jj show:*)"
      "Bash(jj evolog:*)"
      "Bash(jj op log:*)"
      "Bash(jj file list:*)"
      "Bash(jj bookmark list:*)"

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

      # Syncing before edits is the documented first step in this repo
      "Bash(git pull:*)"
      "Bash(git fetch:*)"

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
      "Bash(nix path-info:*)"
      "Bash(nix --version)"

      # Nix builds and checks: sandboxed by the daemon, write only ./result
      "Bash(nix build:*)"
      "Bash(nix flake check:*)"
      "Bash(nix fmt:*)"

      # Read-only service and log inspection
      "Bash(journalctl:*)"
      "Bash(systemctl status:*)"
      "Bash(systemctl list-units:*)"
      "Bash(systemctl --user status:*)"
      "Bash(systemctl --user list-units:*)"
    ];

    # Hard checkpoints. `ask` forces a prompt in every mode, including `auto`,
    # so unlike a "don't push" stated in conversation these cannot be lost to
    # context compaction.
    ask = [
      # Publishing is always an explicit, separate instruction
      "Bash(git push:*)"
      "Bash(jj git push:*)"
      "Bash(gh pr create:*)"
      "Bash(gh pr merge:*)"

      # System activation and store cleanup change state outside the repo
      "Bash(sudo nixos-rebuild:*)"
      "Bash(nix-collect-garbage:*)"
      "Bash(sudo nix-collect-garbage:*)"
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

  env = {
    # Force subagents to use the same model as the main thread
    CLAUDE_CODE_SUBAGENT_MODEL = claudeModel;

    # Size auto-compact to the full 1M context window
    CLAUDE_CODE_AUTO_COMPACT_WINDOW = "1000000";
  };

  # Always show extended thinking for visibility into reasoning
  alwaysThinkingEnabled = true;
}
