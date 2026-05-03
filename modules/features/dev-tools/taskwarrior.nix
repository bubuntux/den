{
  flake.homeModules.taskwarrior =
    {
      pkgs,
      config,
      ...
    }:
    let
      # The upstream hook ships with `#!/usr/bin/env python3`, which fails
      # when python3 isn't on the user's PATH. Pin it to the store python3.
      timewHook = pkgs.runCommand "on-modify.timewarrior" { } ''
        cp ${pkgs.timewarrior}/share/doc/timew/ext/on-modify.timewarrior $out
        chmod +w $out
        substituteInPlace $out \
          --replace-fail '#!/usr/bin/env python3' '#!${pkgs.python3}/bin/python3'
        chmod +x $out
      '';
    in
    {
      programs.taskwarrior = {
        enable = true;
        package = pkgs.taskwarrior3;
        config = {
          hooks.location = "${config.xdg.configHome}/task/hooks";

          # Rank `priority:L` below unprioritized tasks (default coefficient
          # is +1.8, which counterintuitively boosts Low above none).
          urgency.uda.priority.L.coefficient = -1.8;

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
    };
}
