{
  flake.homeModules.gh = _: {
    programs.gh.enable = true;
    programs.gh.gitCredentialHelper.enable = true;
    programs.gh.settings.git_protocol = "ssh";
  };
}
