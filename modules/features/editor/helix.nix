{
  flake.homeModules.helix =
    { pkgs, lib, ... }:
    {
      programs.helix = {
        enable = true;
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
            name = "nix";
            auto-format = true;
            formatter.command = lib.getExe pkgs.nixfmt;
          }
          {
            name = "typst";
            auto-format = true;
            formatter.command = lib.getExe pkgs.typstyle;
          }
          # {
          #   name = "java";
          #   auto-format = false;
          #   formatter = {
          #     command = lib.getExe pkgs.google-java-format;
          #     args = [ "-" ];
          #   };
          # }
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
