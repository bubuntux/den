{ self, ... }:
{
  flake.modules.homeManager.bugwarrior =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      # taskw is a taskwarrior 2 library: it writes pending.data, which
      # taskwarrior 3 never reads, so a pull would report success and store
      # nothing. taskw-ng is the fork that speaks to 3.x.
      bugwarrior = pkgs.python3Packages.bugwarrior.overridePythonAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace bugwarrior/db.py bugwarrior/services/redmine.py bugwarrior/collect.py \
            --replace-quiet "from taskw import TaskWarriorShellout" \
                            "from taskw_ng import TaskWarrior as TaskWarriorShellout" \
            --replace-quiet "from taskw.exceptions import TaskwarriorError" \
                            "from taskw_ng.exceptions import TaskwarriorError" \
            --replace-quiet "from taskw.task import Task" "from taskw_ng.task import Task"
          substituteInPlace tests/test_db.py \
            --replace-fail "import taskw.task" "import taskw_ng as taskw; import taskw_ng.task"
        '';
        dependencies =
          old.dependencies
          ++ [ pkgs.python3Packages.taskw-ng ]
          ++ pkgs.python3Packages.bugwarrior.optional-dependencies.jira;
        # taskw-ng runs `task --version` at import time and raises without it.
        makeWrapperArgs = (old.makeWrapperArgs or [ ]) ++ [
          "--prefix"
          "PATH"
          ":"
          "${pkgs.taskwarrior3}/bin"
        ];
      });

      configFile = "${config.xdg.configHome}/bugwarrior/bugwarrior.toml";
    in
    {
      key = "den:homeManager.bugwarrior";
      imports = [ self.modules.homeManager.taskwarrior ];

      home.packages = [ bugwarrior ];

      # `bugwarrior uda` prints these; they are the same for every Jira target.
      programs.taskwarrior.config.uda = {
        jiraid = {
          type = "string";
          label = "Jira Issue ID";
        };
        jirasummary = {
          type = "string";
          label = "Jira Summary";
        };
        jiradescription = {
          type = "string";
          label = "Jira Description";
        };
        jiraurl = {
          type = "string";
          label = "Jira URL";
        };
        jirastatus = {
          type = "string";
          label = "Jira Status";
        };
        jiraissuetype = {
          type = "string";
          label = "Issue Type";
        };
        jiraestimate = {
          type = "numeric";
          label = "Estimate";
        };
        jirafixversion = {
          type = "string";
          label = "Fix Version";
        };
        jiracreatedts = {
          type = "date";
          label = "Created At";
        };
        jirasubtasks = {
          type = "string";
          label = "Jira Subtasks";
        };
        jiraparent = {
          type = "string";
          label = "Jira Parent";
        };
        # Arrives through `extra_fields`, which names the UDA after its label.
        jirasprint = {
          type = "string";
          label = "Sprint";
        };

        githubtitle = {
          type = "string";
          label = "Github Title";
        };
        githubbody = {
          type = "string";
          label = "Github Body";
        };
        githubcreatedon = {
          type = "date";
          label = "Github Created";
        };
        githubupdatedat = {
          type = "date";
          label = "Github Updated";
        };
        githubclosedon = {
          type = "date";
          label = "GitHub Closed";
        };
        githubmilestone = {
          type = "string";
          label = "Github Milestone";
        };
        githubrepo = {
          type = "string";
          label = "Github Repo Slug";
        };
        githuburl = {
          type = "string";
          label = "Github URL";
        };
        githubtype = {
          type = "string";
          label = "Github Type";
        };
        githubnumber = {
          type = "numeric";
          label = "Github Issue/PR #";
        };
        githubuser = {
          type = "string";
          label = "Github User";
        };
        githubnamespace = {
          type = "string";
          label = "Github Namespace";
        };
        githubstate = {
          type = "string";
          label = "GitHub State";
        };
        githubdraft = {
          type = "numeric";
          label = "GitHub Draft";
        };
      };

      programs.taskwarrior.config.urgency.user.tag.bw.coefficient = -5.0;
      programs.taskwarrior.config.urgency.uda.jirastatus."In Progress".coefficient = 3.0;
      programs.taskwarrior.config.urgency.user.tag.sprint.coefficient = 3.0;

      # ConditionPathExists, so this is inert until the hand-written config is
      # there rather than a failed unit on every host that installs it.
      systemd.user.services.bugwarrior-pull = {
        Unit = {
          Description = "Pull issues into taskwarrior";
          ConditionPathExists = configFile;
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe' bugwarrior "bugwarrior"} pull --quiet";
        };
      };

      systemd.user.timers.bugwarrior-pull = {
        Unit.Description = "Pull issues into taskwarrior";
        Timer = {
          OnCalendar = "hourly";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
