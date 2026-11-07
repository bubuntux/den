{
  flake.modules.homeManager.neovim =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      jdtlsGradleInitScript = pkgs.writeText "jdtls-gradle-init.gradle" ''
        gradle.projectsEvaluated {
            gradle.rootProject.allprojects { project ->
                project.plugins.withId('java') {
                    def sourceDirectorySets = project.sourceSets.collectMany { [it.java, it.resources] }
                    def allSourceDirs = sourceDirectorySets.collectMany { it.srcDirs }
                    sourceDirectorySets.each { sourceDirectorySet ->
                        def nestedDirs = sourceDirectorySet.srcDirs.findAll { dir ->
                            allSourceDirs.any { other -> other != dir && dir.path.startsWith(other.path + File.separator) }
                        }
                        if (nestedDirs) {
                            sourceDirectorySet.srcDirs = sourceDirectorySet.srcDirs - nestedDirs
                        }
                    }
                }

                // JDT compiles into Buildship's default bin/ output folders, which most repos don't ignore.
                // Put them under build/, which every Gradle repo ignores.
                project.plugins.withId('eclipse') {
                    project.eclipse.classpath.defaultOutputDir = project.file('build/jdtls/default')
                    project.eclipse.classpath.baseSourceOutputDir.set(project.file('build/jdtls'))
                }
            }
        }
      '';
    in
    {
      key = "den:homeManager.neovim#java";

      options.den.neovim.languages.java = lib.mkEnableOption "Java language support";

      config.programs.nixvim = lib.mkIf config.den.neovim.languages.java {
        plugins.treesitter.grammarPackages =
          with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
            groovy
            java
            xml
          ];

        lsp.servers.jdtls = {
          enable = true;
          package = pkgs.jdt-language-server;
          config = {
            filetypes = [ "java" ];
            root_markers = [
              "settings.gradle"
              "settings.gradle.kts"
              "pom.xml"
              "build.gradle"
              "build.gradle.kts"
              ".git"
            ];
            cmd.__raw = ''
              function(dispatchers, config)
                local cache_root = vim.fn.stdpath("cache") .. "/jdtls"
                local root_dir = config and config.root_dir
                local project_key = root_dir and root_dir:gsub("[/:]", "_") or "default"
                local argv = {
                  "jdtls",
                  "-configuration", cache_root .. "/config",
                  "-data", cache_root .. "/workspace/" .. project_key,
                  "--jvm-arg=-javaagent:${pkgs.lombok}/share/java/lombok.jar",
                }
                for arg in string.gmatch(vim.env.JDTLS_JVM_ARGS or "", "%S+") do
                  table.insert(argv, "--jvm-arg=" .. arg)
                end
                return vim.lsp.rpc.start(argv, dispatchers, {
                  cwd = config and config.cmd_cwd,
                  env = config and config.cmd_env,
                })
              end
            '';
            settings.java.import.gradle.arguments =
              "--init-script ${jdtlsGradleInitScript} -Didea.sync.active=true";
            # jdtls runs on nixpkgs openjdk (java.vendor "N/A"), which vendor-checking Gradle plugins reject.
            before_init.__raw = ''
              function(params, config)
                config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
                  java = { import = { gradle = { java = { home = vim.env.JAVA_HOME } } } },
                })
                params.initializationOptions = params.initializationOptions or {}
                params.initializationOptions.settings = config.settings
              end
            '';
          };
        };
      };
    };
}
