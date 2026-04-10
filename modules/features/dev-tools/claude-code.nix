{ self, ... }:
{
  # Home Manager module for Claude Code
  flake.homeModules.claude-code =
    { pkgs, ... }:
    {
      programs.claude-code = {
        enable = true;

        settings = import ./_claude-settings.nix { inherit pkgs; };

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
