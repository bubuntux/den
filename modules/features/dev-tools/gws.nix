{ inputs, ... }:
{
  flake-file.inputs.gws.url = "github:googleworkspace/cli";
  flake-file.inputs.gws.inputs.nixpkgs.follows = "nixpkgs";

  flake.modules.homeManager.gws =
    { pkgs, lib, ... }:
    let
      # The CLI ships ~95 skills: one parent per Workspace service plus its
      # sub-skills, and ~50 recipe-*/persona-* wrappers we don't use. Enable
      # whole families only — a parent links its sub-skills by relative path
      # (../gws-gmail-send/SKILL.md), so a partial family leaves dead links.
      enabledSkills = [
        # Auth, global flags, and security rules; every other skill requires it.
        "gws-shared"

        "gws-gmail"
        "gws-gmail-forward"
        "gws-gmail-read"
        "gws-gmail-reply"
        "gws-gmail-reply-all"
        "gws-gmail-send"
        "gws-gmail-triage"
        "gws-gmail-watch"

        "gws-calendar"
        "gws-calendar-agenda"
        "gws-calendar-insert"

        "gws-docs"
        "gws-docs-write"

        "gws-drive"
        "gws-drive-upload"

        "gws-sheets"
        "gws-sheets-append"
        "gws-sheets-read"

        # Standalone services, no sub-skills.
        "gws-forms"
        "gws-people"
        "gws-slides"
      ];

      skillsDir = inputs.gws + "/skills";
      skills = lib.concatMapAttrs (
        name: type:
        lib.optionalAttrs (type == "directory" && lib.elem name enabledSkills) {
          ${name} = skillsDir + "/${name}";
        }
      ) (builtins.readDir skillsDir);
      missingSkills = lib.subtractLists (lib.attrNames skills) enabledSkills;
    in
    {
      key = "den:homeManager.gws";
      home.packages = [
        inputs.gws.packages.${pkgs.stdenv.hostPlatform.system}.default
        pkgs.google-cloud-sdk
      ];

      # An upstream rename would otherwise silently drop the skill.
      programs.claude-code.skills = lib.warnIf (
        missingSkills != [ ]
      ) "gws: skills missing from googleworkspace/cli: ${lib.concatStringsSep ", " missingSkills}" skills;
    };
}
