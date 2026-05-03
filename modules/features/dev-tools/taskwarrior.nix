{
  flake.homeModules.taskwarrior =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      cfg = config.taskwarriorPomodoro;

      # The upstream hook ships with `#!/usr/bin/env python3`, which fails
      # when python3 isn't on the user's PATH. Pin it to the store python3.
      timewHook = pkgs.runCommand "on-modify.timewarrior" { } ''
        cp ${pkgs.timewarrior}/share/doc/timew/ext/on-modify.timewarrior $out
        chmod +w $out
        substituteInPlace $out \
          --replace-fail '#!/usr/bin/env python3' '#!${pkgs.python3}/bin/python3'
        chmod +x $out
      '';

      # Notifier invoked by the systemd-user timer. Re-queries the active
      # task at fire time so the message reflects real cumulative elapsed
      # ("25m", "50m", "1h 15m"), and silently exits if the task is no
      # longer active (handles stop/done races with the timer).
      pomoNotifier = pkgs.writeTextFile {
        name = "taskwarrior-pomodoro-notify";
        executable = true;
        text = ''
          #!${pkgs.python3}/bin/python3
          import json
          import subprocess
          import sys
          from datetime import datetime, timezone

          uuid = sys.argv[1]
          result = subprocess.run(
              ["${pkgs.taskwarrior3}/bin/task", uuid, "export"],
              capture_output=True,
              text=True,
          )
          if result.returncode != 0 or not result.stdout.strip():
              sys.exit(0)
          tasks = json.loads(result.stdout)
          if not tasks or "start" not in tasks[0]:
              sys.exit(0)
          t = tasks[0]
          desc = t.get("description", "(no description)")
          start = datetime.strptime(t["start"], "%Y%m%dT%H%M%SZ").replace(
              tzinfo=timezone.utc
          )
          minutes = int((datetime.now(timezone.utc) - start).total_seconds() // 60)
          if minutes < 60:
              elapsed = f"{minutes}m"
          else:
              h, m = divmod(minutes, 60)
              elapsed = f"{h}h {m}m" if m else f"{h}h"
          subprocess.run([
              "${pkgs.libnotify}/bin/notify-send",
              "-a", "taskwarrior",
              f"Time check: {desc}",
              f"{elapsed} elapsed — break, switch, or keep going.",
          ])
        '';
      };

      # On-modify hook: detects start/stop transitions and creates or
      # cancels a transient systemd-user timer that fires the notifier.
      # Per-task duration override via the `pomo` UDA (numeric, minutes).
      pomoHook = pkgs.writeTextFile {
        name = "on-modify.pomodoro";
        executable = true;
        text = ''
          #!${pkgs.python3}/bin/python3
          import json
          import subprocess
          import sys

          DEFAULT_MIN = ${toString cfg.durationMinutes}
          REPEAT = ${if cfg.repeat then "True" else "False"}
          NOTIFIER = "${pomoNotifier}"

          original = json.loads(sys.stdin.readline())
          modified = json.loads(sys.stdin.readline())
          print(json.dumps(modified))

          uuid = modified.get("uuid") or original.get("uuid", "")
          if not uuid:
              sys.exit(0)

          unit = f"task-pomodoro-{uuid}"
          was_active = "start" in original
          is_active = "start" in modified
          status = modified.get("status", "pending")

          def stop_unit():
              subprocess.run(
                  ["${pkgs.systemd}/bin/systemctl", "--user", "stop",
                   f"{unit}.timer", f"{unit}.service"],
                  capture_output=True,
              )

          if not was_active and is_active:
              duration = int(modified.get("pomo") or DEFAULT_MIN)
              # Defensive: clear any lingering unit before creating a new one.
              stop_unit()
              args = [
                  "${pkgs.systemd}/bin/systemd-run", "--user", "--quiet",
                  f"--on-active={duration}min",
                  f"--unit={unit}",
              ]
              if REPEAT:
                  args.append(f"--on-unit-active={duration}min")
              args += [NOTIFIER, uuid]
              subprocess.run(args, capture_output=True)
          elif was_active and (not is_active or status != "pending"):
              stop_unit()
        '';
      };
    in
    {
      options.taskwarriorPomodoro = {
        durationMinutes = lib.mkOption {
          type = lib.types.ints.positive;
          default = 25;
          description = ''
            Default minutes between Pomodoro check-in notifications after
            `task start`. Override per task with `task <id> modify pomo:N`.
          '';
        };
        repeat = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Repeat notifications every duration interval until the task
            stops or completes. When false, fires once.
          '';
        };
      };

      config = {
        programs.taskwarrior = {
          enable = true;
          package = pkgs.taskwarrior3;
          config = {
            hooks.location = "${config.xdg.configHome}/task/hooks";

            # Rank `priority:L` below unprioritized tasks (default coefficient
            # is +1.8, which counterintuitively boosts Low above none).
            urgency.uda.priority.L.coefficient = -1.8;

            # Numeric UDA for per-task Pomodoro duration override (minutes).
            uda.pomo.type = "numeric";
            uda.pomo.label = "Pomodoro";

            # Contexts: `read` filters reports; `write` auto-tags new tasks
            # added while the context is active. `focus` is a view-only lens
            # (no write filter) that surfaces actionable work across projects.
            context.work.read = "+work";
            context.work.write = "+work";
            context.personal.read = "+personal";
            context.personal.write = "+personal";
            context.focus.read = "+next or +TODAY or +OVERDUE or +ACTIVE";
          };
        };

        home.packages = with pkgs; [
          timewarrior
          taskwarrior-tui
        ];

        home.shellAliases.tt = "taskwarrior-tui";

        # Bridge taskwarrior <-> timewarrior: `task start`/`task stop`
        # automatically starts/stops a matching timewarrior interval.
        xdg.configFile."task/hooks/on-modify.timewarrior" = {
          source = timewHook;
          executable = true;
        };

        # Pomodoro: schedule a notification N minutes after `task start`.
        xdg.configFile."task/hooks/on-modify.pomodoro" = {
          source = pomoHook;
          executable = true;
        };
      };
    };
}
