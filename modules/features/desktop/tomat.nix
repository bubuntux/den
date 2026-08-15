{
  flake.modules.homeManager.tomat =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      sessionTarget = config.wayland.systemd.target;

      notificationIcon = "alarm-symbolic";

      # tomat's own notification has a hardcoded title, so this replaces it.
      notify = pkgs.writeShellApplication {
        name = "pomodoro-notify";
        runtimeInputs = with pkgs; [
          coreutils
          jq
          libnotify
          taskwarrior3
        ];
        text = ''
          case "$1" in
            work-end) title="Pomodoro done" ;;
            break-end | long-break-end) title="Back to work" ;;
            *) title="Pomodoro" ;;
          esac

          active=$(task rc.context=none rc.confirmation=off +ACTIVE export 2>/dev/null || echo '[]')
          description=$(jq -r '.[0].description // ""' <<<"$active")
          project=$(jq -r '.[0].project // ""' <<<"$active")
          due=$(jq -r '.[0].due // ""' <<<"$active")

          meta=$project
          if [ -n "$due" ]; then
            # Fixed-width UTC either side, so a string compare is a date compare.
            if [[ $due < $(date -u +%Y%m%dT%H%M%SZ) ]]; then
              suffix=OVERDUE
            else
              suffix="due ''${due:0:4}-''${due:4:2}-''${due:6:2}"
            fi
            if [ -n "$meta" ]; then meta="$meta · $suffix"; else meta=$suffix; fi
          fi

          if [ -n "$description" ] && [ -n "$meta" ]; then
            body="$description"$'\n'"$meta"
          else
            body="$description$meta"
          fi

          notify-send -a pomodoro -i ${notificationIcon} -t 0 "$title" "$body"
        '';
      };

      phaseHook = phase: {
        cmd = lib.getExe notify;
        args = [ phase ];
      };

      settings = {
        timer = {
          work = 25.0;
          break = 5.0;
          long_break = 15.0;
          sessions = 4;
          auto_advance = "to-break";
        };

        sound.mode = "none";

        notification.enabled = false;

        display = {
          text_format = "{icon} {time} {state}";
          # Empty text is what drops the widget from both bars while idle.
          text_format_idle = "";
          icons = {
            work = "󰔟";
            break = "󰅶";
            long_break = "󰢠";
            play = "󰐊";
            pause = "󰏤";
            stop = "󰓛";
          };
        };

        # These fire on a timed transition, not on `tomat skip`.
        hooks = {
          on_work_end = phaseHook "work-end";
          on_break_end = phaseHook "break-end";
          on_long_break_end = phaseHook "long-break-end";
        };
      };

      configFile = (pkgs.formats.toml { }).generate "tomat-config.toml" settings;
    in
    {
      key = "den:homeManager.tomat";

      config = lib.mkIf config.programs.taskwarrior.enable {
        home.packages = [ pkgs.tomat ];

        xdg.configFile."tomat/config.toml".source = configFile;

        systemd.user.services.tomat = {
          Unit = {
            Description = "Pomodoro timer daemon";
            Documentation = "https://github.com/jolars/tomat";
            PartOf = [ sessionTarget ];
            After = [ sessionTarget ];
            X-Reload-Triggers = [ "${configFile}" ];
          };
          Service = {
            # `daemon start` forks and returns; only `daemon run` stays foreground.
            ExecStart = "${lib.getExe pkgs.tomat} daemon run";
            Restart = "on-failure";
          };
          Install.WantedBy = [ sessionTarget ];
        };
      };
    };
}
