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
    let
      # The toolkit ships ~90 skills covering nearly every AWS service. Enable
      # only the ones matching services we actually use, keyed by the skill's
      # directory name (repo-wide unique).
      enabledSkills = [
        # Basics
        "signing-in-to-aws"
        "aws-iam"
        "aws-sdk-python-usage"
        "aws-observability"
        "aws-billing-and-cost-management"

        # S3 (storing-and-querying-vectors is S3 Vectors, used for Bedrock RAG)
        "securing-s3-buckets"
        "querying-aws-s3"
        "storing-and-querying-vectors"

        # EC2 (aws-compute is the core instance-selection skill)
        "aws-compute"
        "launching-ec2-instance-with-best-practices"
        "setting-up-ec2-instance-profiles"

        # Bedrock
        "amazon-bedrock"

        # SageMaker (the toolkit's only SageMaker skill: SQL over catalog metadata)
        "querying-aws-sagemaker-catalog"
      ];

      # Skills are nested (core-skills/* and specialized-skills/<group>/*), so
      # walk the tree and pick out the enabled ones wherever they live.
      collect =
        dir:
        lib.concatMapAttrs (
          # Key each skill by its readDir entry name (a context-free string)
          # rather than baseNameOf on a path, which Nix forbids as an
          # attribute name.
          name: type:
          if type != "directory" then
            { }
          else if builtins.pathExists (dir + "/${name}/SKILL.md") then
            lib.optionalAttrs (lib.elem name enabledSkills) { ${name} = dir + "/${name}"; }
          else
            collect (dir + "/${name}")
        ) (builtins.readDir dir);

      skills = collect (inputs.aws-agent-toolkit + "/skills");
      missingSkills = lib.subtractLists (lib.attrNames skills) enabledSkills;
    in
    {
      home.packages = [ pkgs.awscli2 ];

      # An upstream rename would otherwise silently drop the skill.
      programs.claude-code.skills =
        lib.warnIf (missingSkills != [ ])
          "aws: skills missing from agent-toolkit-for-aws: ${lib.concatStringsSep ", " missingSkills}"
          skills;
    };
}
