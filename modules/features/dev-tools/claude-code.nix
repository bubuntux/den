{ self, ... }:
{
  # Home Manager module for Claude Code
  flake.homeModules.claude-code =
    { pkgs, ... }:
    let
      claudeModel = "opus";
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
      programs.claude-code = {
        enable = true;

        # Global CLAUDE.md — applies to all projects
        memory.text = ''
          # Global Instructions

          ## Style
          - Be concise and direct — avoid filler phrases and unnecessary caveats
          - Use plain language; avoid jargon unless contextually appropriate
          - Never add emojis unless explicitly requested
          - When referencing code, include `file_path:line_number`

          ## Git
          - Always `git pull` before starting work
          - Present changes and proposed commit message for approval before committing
          - Never force-push, amend published commits, or skip hooks without explicit permission

          # Workflow Orchestration

          ## 1. Plan Mode Default
          - Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
          - If something goes sideways, STOP and re-plan immediately — don't keep pushing
          - Use plan mode for verification steps, not just building
          - Write detailed specs upfront to reduce ambiguity

          ## 2. Subagent Strategy
          - Use subagents liberally to keep main context window clean
          - Offload research, exploration, and parallel analysis to subagents
          - For complex problems, throw more compute at it via subagents
          - One task per subagent for focused execution

          ## 3. Self-Improvement Loop
          - After ANY correction from the user: update `tasks/lessons.md` with the pattern
          - Write rules for yourself that prevent the same mistake
          - Ruthlessly iterate on these lessons until mistake rate drops
          - Review lessons at session start for relevant project

          ## 4. Verification Before Done
          - Never mark a task complete without proving it works
          - Diff behavior between main and your changes when relevant
          - Ask yourself: "Would a staff engineer approve this?"
          - Run tests, check logs, demonstrate correctness

          ## 5. Demand Elegance (Balanced)
          - For non-trivial changes: pause and ask "is there a more elegant way?"
          - If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
          - Skip this for simple, obvious fixes — don't over-engineer
          - Challenge your own work before presenting it

          ## 6. Autonomous Bug Fixing
          - When given a bug report: just fix it. Don't ask for hand-holding
          - Point at logs, errors, failing tests — then resolve them
          - Zero context switching required from the user
          - Go fix failing CI tests without being told how

          ## 7. Context Management
          - Summarize findings before they scroll out of context — don't rely on re-reading
          - When context window hits ~70%, proactively compress by offloading completed work to subagents
          - Start new conversations for unrelated tasks rather than overloading one session

          ## 8. Research Before Writing
          - Read the existing code patterns in the file/module before writing new code — match the style
          - Check for existing utilities/helpers before creating new ones
          - Grep the codebase for similar implementations before reinventing

          ## 9. Incremental Delivery
          - Show working state after each meaningful step, don't go dark for 10 tool calls
          - For multi-file changes, verify each file compiles/evaluates before moving to the next
          - Surface blocking decisions early — don't bury them in a wall of output

          ## 10. Error Recovery
          - On the second failure of the same approach, stop and try a fundamentally different strategy
          - When a build/test fails, read the *full* error before attempting a fix — don't pattern-match on the first line
          - If stuck for more than 3 attempts, ask the user rather than spiraling

          ## 11. Scope Discipline
          - If you notice an unrelated issue while working, note it but don't fix it — stay on task
          - Resist the urge to "clean up" adjacent code — that's a separate PR
          - One concern per commit, one theme per PR

          # Task Management
          1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
          2. **Verify Plan**: Check in before starting implementation
          3. **Track Progress**: Mark items complete as you go
          4. **Explain Changes**: High-level summary at each step
          5. **Document Results**: Add review section to `tasks/todo.md`
          6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

          # Core Principles
          - **Simplicity First**: Make every change as simple as possible. Impact minimal code.
          - **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
          - **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.
        '';

        settings = {
          # Prefer the most advanced model
          model = claudeModel;
          effortLevel = "high";

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
              "Bash(git *log*)"
              "Bash(git *show*)"
              "Bash(git *status*)"
              "Bash(git *diff*)"
              "Bash(git *branch*)"
              "Bash(git *tag*)"
              "Bash(git *remote*)"
              "Bash(git *rev-parse*)"
              "Bash(git *ls-files*)"

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
