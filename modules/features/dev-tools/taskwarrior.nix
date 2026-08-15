{
  flake.modules = {
    homeManager.taskwarrior =
      {
        pkgs,
        config,
        lib,
        ...
      }:
      let
        # Upstream's shebang and its bare `timew` both miss from a user unit.
        timewarriorHook = pkgs.runCommand "on-modify.timewarrior" { } ''
          cp ${pkgs.timewarrior}/share/doc/timew/ext/on-modify.timewarrior $out
          chmod +w $out
          substituteInPlace $out \
            --replace-fail '#!/usr/bin/env python3' '#!${pkgs.python3}/bin/python3' \
            --replace-fail "'timew'," "'${pkgs.timewarrior}/bin/timew',"
          chmod +x $out
        '';

        # Taskwarrior allows many active tasks, timewarrior one open interval.
        # `rc.hooks=off` keeps this stop out of the hooks below.
        exclusiveHook = pkgs.writeTextFile {
          name = "on-modify.exclusive";
          executable = true;
          text = ''
            #!${pkgs.python3}/bin/python3
            import json
            import subprocess
            import sys

            TASK = "${pkgs.taskwarrior3}/bin/task"

            original = json.loads(sys.stdin.readline())
            modified = json.loads(sys.stdin.readline())
            print(json.dumps(modified))

            uuid = modified.get("uuid", "")
            if uuid and "start" in modified and "start" not in original:
                try:
                    subprocess.run(
                        [TASK, "rc.hooks=off", "rc.confirmation=off", "rc.context=none",
                         "+ACTIVE", "uuid.not:" + uuid, "stop"],
                        capture_output=True,
                        timeout=10,
                    )
                # Raising would abort the `task start` that triggered this.
                except (subprocess.SubprocessError, OSError):
                    pass
          '';
        };

        # tomat exits 0 with no daemon; a non-zero hook would abort the change.
        pomodoroHook = pkgs.writeTextFile {
          name = "on-modify.pomodoro";
          executable = true;
          text = ''
            #!${pkgs.python3}/bin/python3
            import json
            import subprocess
            import sys

            TOMAT = "${lib.getExe pkgs.tomat}"

            original = json.loads(sys.stdin.readline())
            modified = json.loads(sys.stdin.readline())
            print(json.dumps(modified))

            was_active = "start" in original
            is_active = "start" in modified
            status = modified.get("status", "pending")

            if not was_active and is_active:
                minutes = int(modified.get("pomo") or 0)
                args = [TOMAT, "start"] + (["-w", str(minutes)] if minutes else [])
                subprocess.run(args, capture_output=True)
            elif was_active and (not is_active or status != "pending"):
                subprocess.run([TOMAT, "stop"], capture_output=True)
          '';
        };
      in
      {
        key = "den:homeManager.taskwarrior";

        programs.taskwarrior = {
          enable = true;
          package = pkgs.taskwarrior3;
          config = {
            hooks.location = "${config.xdg.configHome}/task/hooks";

            # Rank `priority:L` below unprioritized tasks (default coefficient
            # is +1.8, which counterintuitively boosts Low above none).
            urgency.uda.priority.L.coefficient = -1.8;

            # Personal tasks outrank work tasks in nearly all cases. Only
            # `+next` (15.0) or imminently overdue work (≤12.0) wins.
            urgency.user.tag.personal.coefficient = 10.0;

            # Per-task override of tomat's work duration, in minutes.
            uda.pomo.type = "numeric";
            uda.pomo.label = "Pomodoro";

            context.work.read = "+work";
            context.work.write = "+work";
            context.personal.read = "+personal";
            context.personal.write = "+personal";
            # View-only lens: no write filter, so it never tags new tasks.
            context.focus.read = "+next or +TODAY or +OVERDUE or +ACTIVE";
          };
        };

        home.packages = with pkgs; [
          timewarrior
          taskwarrior-tui
        ];

        home.shellAliases.tt = "taskwarrior-tui";

        xdg.configFile."task/hooks/on-modify.exclusive" = {
          source = exclusiveHook;
          executable = true;
        };

        # `task start`/`task stop` starts and stops a matching timewarrior interval.
        xdg.configFile."task/hooks/on-modify.timewarrior" = {
          source = timewarriorHook;
          executable = true;
        };

        xdg.configFile."task/hooks/on-modify.pomodoro" = {
          source = pomodoroHook;
          executable = true;
        };

        # ExecStop covers logout and shutdown, not suspend. Without the two
        # overrides a context hides the task, and 3+ matches prompt.
        systemd.user.services.taskwarrior-stop-active = {
          Unit.Description = "Stop active taskwarrior tasks on logout/shutdown";
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.coreutils}/bin/true";
            ExecStop = "-${pkgs.taskwarrior3}/bin/task rc.confirmation=off rc.context=none +ACTIVE stop";
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
  };
}
