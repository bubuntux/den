{
  flake.modules.homeManager.neovim =
    { config, lib, ... }:
    let
      gradleLanguages = lib.filter (language: config.den.neovim.languages.${language}) [
        "java"
        "kotlin"
      ];
    in
    {
      key = "den:homeManager.neovim#gradle";

      config.programs.nixvim = lib.mkIf (gradleLanguages != [ ]) {
        globals.den_format_after_save = lib.genAttrs gradleLanguages (_: true);

        plugins.conform-nvim.settings = {
          formatters_by_ft = lib.genAttrs gradleLanguages (_: [ "spotless" ]);
          formatters.spotless = {
            command = "./gradlew";
            stdin = true;
            cwd.__raw = ''require("conform.util").root_file({ "gradlew" })'';
            require_cwd = true;
            args.__raw = ''
              function(self, ctx)
                local root = vim.fs.root(ctx.filename, "gradlew")
                local project_dir = vim.fs.root(ctx.filename, { "build.gradle", "build.gradle.kts" }) or root
                local relative_dir = vim.fs.relpath(root, project_dir) or "."
                local project_path = relative_dir == "." and ":" or (":" .. relative_dir:gsub("/", ":") .. ":")
                local language = vim.bo[ctx.buf].filetype == "kotlin" and "Kotlin" or "Java"
                return {
                  "--daemon", "-q", "-a",
                  project_path .. "spotless" .. language, "--rerun",
                  "-x", "compile" .. language,
                  "-PspotlessIdeHook=" .. ctx.filename,
                  "-PspotlessIdeHookUseStdIn",
                  "-PspotlessIdeHookUseStdOut",
                }
              end
            '';
          };
        };
      };
    };
}
