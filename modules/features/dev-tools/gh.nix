{
  flake.modules.homeManager.gh = {
    key = "den:homeManager.gh";
    programs.gh.enable = true;
    programs.gh.gitCredentialHelper.enable = true;
    programs.gh.settings.git_protocol = "ssh";
  };
}
