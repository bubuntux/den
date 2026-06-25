{ inputs, ... }:
{
  # Source-only input for AWS's official agent-skills toolkit. Skills live in
  # this repo, not in the awscli2 package, so it is fetched separately.
  flake-file.inputs.aws-agent-toolkit = {
    url = "github:aws/agent-toolkit-for-aws";
    flake = false;
  };

  flake.homeModules.aws =
    { pkgs, lib, ... }:
    {
      home.packages = [ pkgs.awscli2 ];

      # Skills are nested (core-skills/* and specialized-skills/<group>/*), so
      # walk the tree and map every directory holding a SKILL.md into Claude
      # Code, keyed by its (repo-wide unique) leaf name.
      programs.claude-code.skills =
        let
          # Recurse from a directory, keying each skill by its readDir entry
          # name (a context-free string) rather than baseNameOf on a path,
          # which Nix forbids as an attribute name.
          collect =
            dir:
            lib.concatMapAttrs (
              name: type:
              if type != "directory" then
                { }
              else if builtins.pathExists (dir + "/${name}/SKILL.md") then
                { ${name} = dir + "/${name}"; }
              else
                collect (dir + "/${name}")
            ) (builtins.readDir dir);
        in
        collect (inputs.aws-agent-toolkit + "/skills");
    };
}
