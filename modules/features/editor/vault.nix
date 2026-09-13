{ self, ... }:
{
  flake.modules.homeManager.vault =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      vaults = config.den.vaults;
      tomlFormat = pkgs.formats.toml { };

      absPath = vault: "${config.home.homeDirectory}/${vault.path}";
      dictPath = vault: "${absPath vault}/${vault.dictionary}";
      usesHarper = vault: lib.elem "harper-ls" vault.languageServers;

      moxideToml =
        vault:
        lib.recursiveUpdate {
          daily_notes_folder = vault.dailyNotes.folder;
          dailynote = vault.dailyNotes.format;
          new_file_folder_path = "";
          excluded_folders = [
            ".helix"
            ".obsidian"
          ];
          unresolved_diagnostics = true;
          heading_completions = true;
          title_headings = true;
          include_md_extension_wikilink = false;
        } vault.moxide;

      harperConfig =
        vault:
        lib.recursiveUpdate {
          workspaceDictPath = dictPath vault;
          dialect = "American";
          diagnosticSeverity = "hint";
          linters = {
            SpellCheck = true;
            SentenceCapitalization = false;
            LongSentences = false;
            RepeatedWords = true;
          };
          markdown.IgnoreLinkTitle = true;
        } vault.harper;

      helixLanguagesToml =
        vault:
        {
          language = [
            {
              name = "markdown";
              language-servers = vault.languageServers;
            }
          ];
        }
        // lib.optionalAttrs (usesHarper vault) {
          language-server.harper-ls.config.harper-ls = harperConfig vault;
        };

      helixConfigToml =
        vault: lib.recursiveUpdate { editor.soft-wrap.wrap-at-text-width = true; } vault.helixSettings;

      # Read per-directory from the vault root, so these are root-relative and
      # `.helix/` excludes the file itself.
      helixIgnore =
        vault:
        lib.concatLines (
          [
            ".obsidian/"
            ".helix/"
            ".moxide.toml"
          ]
          ++ lib.optional (usesHarper vault) vault.dictionary
        );

      vaultOptions = {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            example = "Documents/vault";
            description = ''
              Vault directory, relative to the user's home. The generated
              `.moxide.toml` makes it a Helix root, so markdown-oxide indexes
              this directory and nothing above it.
            '';
          };

          dailyNotes = {
            folder = lib.mkOption {
              type = lib.types.str;
              default = "journal";
              description = "Vault-relative folder holding the dated notes.";
            };
            format = lib.mkOption {
              type = lib.types.str;
              default = "%Y/%m/%Y-%m-%d";
              example = "%Y-%m-%d";
              description = ''
                Daily note filename, in chrono's strftime syntax. Obsidian
                states the same thing in moment.js syntax, so the two files
                disagree unless both are changed; see `checkObsidian`.
              '';
            };
          };

          languageServers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "markdown-oxide"
              "harper-ls"
            ];
            description = ''
              Language servers Helix runs for markdown inside this vault,
              replacing the global list. Naming `harper-ls` also installs it.
            '';
          };

          dictionary = lib.mkOption {
            type = lib.types.str;
            default = ".harper-dict.txt";
            description = ''
              Vault-relative harper dictionary, created empty if absent. Keep
              it outside `.helix/`, whose contents are hashed by the trust
              grant -- adding a word there would revoke trust.
            '';
          };

          trust = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether to list the vault in Helix's `workspace-trust.trusted`
              globs. Off means running `:workspace-trust` by hand, again after
              every rebuild that changes `.helix/`.
            '';
          };

          checkObsidian = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether activation warns when `.obsidian/daily-notes.json`
              disagrees with `dailyNotes`. Nothing under `.obsidian/` is
              written -- Obsidian owns those files.
            '';
          };

          moxide = lib.mkOption {
            type = tomlFormat.type;
            default = { };
            example.hover = false;
            description = "Extra `.moxide.toml` settings, merged over the defaults.";
          };

          harper = lib.mkOption {
            type = tomlFormat.type;
            default = { };
            example.linters.BoringWords = true;
            description = "Extra harper-ls settings, merged over the defaults.";
          };

          helixSettings = lib.mkOption {
            type = tomlFormat.type;
            default = { };
            example.editor.text-width = 100;
            description = ''
              Extra `.helix/config.toml` settings, merged over the defaults.
              Helix concatenates lists here, so `editor.rulers` can be
              extended but never cleared.
            '';
          };
        };
      };
    in
    {
      key = "den:homeManager.vault";
      imports = [ self.modules.homeManager.helix ];

      options.den.vaults = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule vaultOptions);
        default = { };
        description = ''
          Obsidian-style markdown vaults to set up for Helix. Each gets a
          `.moxide.toml` and a `.helix/` overriding the global markdown setup
          for that directory only.
        '';
      };

      config = lib.mkIf (vaults != { }) {
        assertions = lib.mapAttrsToList (name: vault: {
          assertion = vault.path != "" && !lib.hasPrefix "/" vault.path;
          message = "den.vaults.${name}.path must be a non-empty path relative to the home directory.";
        }) vaults;

        home.file = lib.mkMerge (
          lib.mapAttrsToList (name: vault: {
            "${vault.path}/.moxide.toml".source = tomlFormat.generate "${name}-moxide.toml" (moxideToml vault);
            "${vault.path}/.helix/languages.toml".source = tomlFormat.generate "${name}-vault-languages.toml" (
              helixLanguagesToml vault
            );
            "${vault.path}/.helix/config.toml".source = tomlFormat.generate "${name}-vault-config.toml" (
              helixConfigToml vault
            );
            "${vault.path}/.helix/ignore".text = helixIgnore vault;
          }) vaults
        );

        programs.helix = {
          extraPackages = lib.optional (lib.any usesHarper (lib.attrValues vaults)) pkgs.harper;

          settings.editor.workspace-trust.trusted = lib.mapAttrsToList (_: absPath) (
            lib.filterAttrs (_: vault: vault.trust) vaults
          );
        };

        home.activation.vaults = lib.hm.dag.entryAfter [ "writeBoundary" ] (
          lib.concatStrings (
            lib.mapAttrsToList (
              name: vault:
              lib.optionalString (usesHarper vault) ''
                mkdir -p "$(dirname ${lib.escapeShellArg (dictPath vault)})"
                [ -e ${lib.escapeShellArg (dictPath vault)} ] || touch ${lib.escapeShellArg (dictPath vault)}
              ''
              + lib.optionalString vault.checkObsidian ''
                vaultDailyNotes=${lib.escapeShellArg "${absPath vault}/.obsidian/daily-notes.json"}
                if [ -f "$vaultDailyNotes" ]; then
                  vaultFolder=$(${lib.getExe pkgs.jq} -r '.folder // ""' "$vaultDailyNotes")
                  vaultFormat=$(${lib.getExe pkgs.jq} -r '.format // "YYYY-MM-DD"' "$vaultDailyNotes" \
                    | ${lib.getExe pkgs.gnused} -e 's/YYYY/%Y/g' -e 's/MM/%m/g' -e 's/DD/%d/g')
                  if [ "$vaultFolder" != ${lib.escapeShellArg vault.dailyNotes.folder} ] \
                    || [ "$vaultFormat" != ${lib.escapeShellArg vault.dailyNotes.format} ]; then
                    echo "warning: vault '${name}' daily notes disagree; [[today]] and Obsidian will write to different paths" >&2
                    echo "  nix:      ${vault.dailyNotes.folder} ${vault.dailyNotes.format}" >&2
                    echo "  obsidian: $vaultFolder $vaultFormat" >&2
                  fi
                fi
              ''
            ) vaults
          )
        );
      };
    };
}
