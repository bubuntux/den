{ self, ... }:
{
  flake.modules.homeManager.neovim =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      key = "den:homeManager.neovim#kotlin";

      options.den.neovim.languages.kotlin = lib.mkEnableOption "Kotlin language support";

      config.programs.nixvim = lib.mkIf config.den.neovim.languages.kotlin {
        plugins.treesitter.grammarPackages =
          with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
            groovy
            kotlin
            xml
          ];
        lsp.servers.kotlin_lsp = {
          enable = true;
          package = pkgs.callPackage "${self}/modules/features/dev-tools/_kotlin-lsp.nix" { };
          config = {
            cmd = [
              "kotlin-lsp"
              "--stdio"
            ];
            filetypes = [ "kotlin" ];
            root_markers = [
              "settings.gradle"
              "settings.gradle.kts"
              "build.gradle"
              "build.gradle.kts"
              "pom.xml"
              ".git"
            ];
          };
        };
      };
    };
}
