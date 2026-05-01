{
  flake.homeModules.taskwarrior =
    {
      pkgs,
      config,
      ...
    }:
    {
      programs.taskwarrior = {
        enable = true;
        package = pkgs.taskwarrior3;
        config.hooks.location = "${config.xdg.configHome}/task/hooks";
      };

      home.packages = with pkgs; [
        timewarrior
        taskwarrior-tui
      ];

      # Bridge taskwarrior <-> timewarrior: `task start`/`task stop`
      # automatically starts/stops a matching timewarrior interval.
      xdg.configFile."task/hooks/on-modify.timewarrior" = {
        source = "${pkgs.timewarrior}/share/doc/timew/ext/on-modify.timewarrior";
        executable = true;
      };
    };
}
