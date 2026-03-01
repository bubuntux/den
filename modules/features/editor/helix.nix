{
  flake.homeModules.helix =
    { pkgs, lib, ... }:
    {
      programs.helix = {
        enable = true;
        defaultEditor = lib.mkDefault true;
        settings = {
          theme = "onedark";
          editor = {
            mouse = false;
            true-color = true;
            soft-wrap.enable = true;
            line-number = "relative";
            rulers = [
              80
              120
            ];

            cursor-shape = {
              insert = "bar";
              normal = "block";
              select = "underline";
            };

            lsp.display-messages = true;
            file-picker.hidden = false;
          };
          keys = {
            normal = {
              esc = [
                "collapse_selection"
                "keep_primary_selection"
              ];
              space.space = "file_picker";
              space.w = ":w";
              space.q = ":q";

              # Lazygit
              C-g = [
                ":write-all"
                ":new"
                (":insert-output " + lib.getExe pkgs.lazygit)
                ":buffer-close!"
                ":redraw"
                ":reload-all"
              ];
            };
          };
        };
        extraPackages = with pkgs; [
          bash-language-server
          yaml-language-server

          vscode-langservers-extracted

          dockerfile-language-server
          docker-compose-language-service

          # gcc
          lldb
          libgcc
          gcc

          # Toml
          taplo

          # Markdown
          marksman
          markdown-oxide

          # Nix
          nil
          nixd

          # Typst
          tinymist
          typstyle

          # ty
          # ruff
          # python313Packages.python-lsp-server

          # # Rust
          # cargo
          # clippy
          # rustc
          # rustfmt
          # rust-analyzer

          # # Go
          # gopls
          # golangci-lint
          # golangci-lint-langserver
          # delve

        ];
        languages.language = [
          {
            name = "bash";
            auto-format = true;
            formatter.command = lib.getExe pkgs.shfmt;
          }
          {
            name = "json";
            auto-format = true;
            formatter.command = lib.getExe pkgs.biome;
            formatter.args = [
              "format"
              "--stdin-file-path"
              "file.json"
            ];
          }
          {
            name = "markdown";
            auto-format = true;
            formatter.command = lib.getExe pkgs.mdformat;
            formatter.args = [ "-" ];
          }
          {
            name = "nix";
            auto-format = true;
            formatter.command = lib.getExe pkgs.nixfmt;
          }
          {
            name = "toml";
            auto-format = true;
            formatter.command = lib.getExe pkgs.taplo;
            formatter.args = [
              "fmt"
              "-"
            ];
          }
          {
            name = "typst";
            auto-format = true;
            formatter.command = lib.getExe pkgs.typstyle;
          }
        ];
        ignores = [
          ".build/"
          "*.class"
          ".direnv"
          "!.gitattributes"
          "!.gitignore"
          ".gradle"
          "target/"
        ];
      };
    };
}
