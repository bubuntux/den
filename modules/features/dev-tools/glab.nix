{ inputs, ... }:
{
  # Source-only input pinning the GitLab CLI repo, used to read its bundled
  # agent skills at eval time (IFD-free; reading pkgs.glab.src would force a
  # build during evaluation). The binary itself comes from nixpkgs below.
  flake-file.inputs.glab-cli = {
    url = "gitlab:gitlab-org/cli";
    flake = false;
  };

  flake.homeModules.glab =
    { pkgs, lib, ... }:
    {
      home.packages = [ pkgs.glab ];

      # glab ships agent skills in-repo (glab, glab-stack). Map each into
      # Claude Code, mirroring the gws pattern.
      programs.claude-code.skills =
        let
          skillsDir = inputs.glab-cli + "/internal/commands/skills/bundled/assets";
          dirs = lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsDir);
        in
        builtins.mapAttrs (name: _: skillsDir + "/${name}") dirs;
    };
}
