{
  self,
  inputs,
  ...
}:
{
  # Home Manager module for user juliogm
  flake.homeModules.user-juliogm =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      jsonFormat = pkgs.formats.json { };
      claudeBaseSettings = import "${self}/modules/features/dev-tools/_claude-settings.nix" {
        inherit pkgs;
      };
      settingsFile = jsonFormat.generate "claude-base-settings.json" (
        claudeBaseSettings // { "$schema" = "https://json.schemastore.org/claude-code-settings.json"; }
      );
    in
    {
      imports = with self.homeModules; [
        profile-developer
        aws
        glab
        gws
        xdg
      ];

      # Prevent HM from managing settings.json as a read-only symlink,
      # so Claude Code plugins can write to it imperatively.
      programs.claude-code.settings = lib.mkForce { };

      # Write Nix-defined settings as a mutable file, merging with any
      # existing imperative changes (plugins, etc.) on each activation.
      home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        target="$HOME/.claude/settings.json"
        mkdir -p "$HOME/.claude"
        if [ -f "$target" ] && [ ! -L "$target" ]; then
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
            "${settingsFile}" "$target" \
            > "$target.tmp"
          mv "$target.tmp" "$target"
        else
          rm -f "$target"
          cp "${settingsFile}" "$target"
          chmod 644 "$target"
        fi
      '';

      # awscli2 and glab are provided by the aws/glab feature modules (which
      # also wire up their Claude Code skills).
      home.packages = with pkgs; [
        acli
        src-cli
        toolhive
      ];

      # Language servers Helix auto-detects when their binaries are on PATH.
      # Docker LSPs are already provided by the shared helix module.
      programs.helix.extraPackages = with pkgs; [
        kotlin-language-server
        jdt-language-server
        terraform-ls
        python3Packages.python-lsp-server
        ruff
      ];

      # Git user configuration (decrypted from sops secret via bind mount)
      programs.git.includes = [ { path = "/run/secrets-host/git_config"; } ];

      # jj identity (decrypted from sops secret via bind mount). jj has no
      # `includes`, so the snippet is loaded via the conf.d config directory.
      xdg.configFile."jj/conf.d/identity.toml".source =
        config.lib.file.mkOutOfStoreSymlink "/run/secrets-host/jj_config";

      # Sign own commits with the work SSH key (id_rsa is the container's key,
      # symlinked from the ssh_private_key/ssh_public_key sops secrets).
      programs.jujutsu.settings.signing = {
        behavior = "own";
        backend = "ssh";
        key = "~/.ssh/id_rsa.pub";
      };

      # SSH host configuration (decrypted from sops secret via bind mount)
      programs.ssh.includes = [ "/run/secrets-host/ssh_config" ];

      programs.bash.initExtra = ''
        for f in "$HOME"/.*-kube-profile; do
          [ -f "$f" ] && . "$f"
        done
      '';

      # Same kube-profile sourcing for zsh. The (N) nullglob qualifier keeps
      # zsh from erroring when no profile files exist (unlike bash, zsh treats
      # an unmatched glob as an error).
      programs.zsh.initContent = ''
        for f in "$HOME"/.*-kube-profile(N); do
          [ -f "$f" ] && . "$f"
        done
      '';
    };

  # Standalone Home Manager configuration for non-NixOS systems
  flake.homeConfigurations.juliogm = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    modules = [
      self.homeModules.user-juliogm
      self.homeModules.zsh
      self.homeModules.nix
      self.homeModules.sops
      self.homeModules.auto-upgrade
      (
        { config, lib, ... }:
        {
          home.username = "juliogm";
          home.homeDirectory = "/home/juliogm";
          targets.genericLinux.enable = true;

          sops.age.sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
          sops.secrets.git_config.sopsFile = "${self}/secrets/juliogm.yaml";
          sops.secrets.jj_config.sopsFile = "${self}/secrets/juliogm.yaml";
          sops.secrets.ssh_config.sopsFile = "${self}/secrets/juliogm.yaml";
          programs.git.includes = lib.mkForce [
            { path = config.sops.secrets.git_config.path; }
          ];
          xdg.configFile."jj/conf.d/identity.toml".source = lib.mkForce (
            config.lib.file.mkOutOfStoreSymlink config.sops.secrets.jj_config.path
          );
          programs.ssh.includes = lib.mkForce [
            config.sops.secrets.ssh_config.path
          ];

        }
      )
    ];
  };

  # NixOS module for user juliogm (used inside the work container)
  flake.nixosModules.user-juliogm = _: {
    # zsh as juliogm's login shell inside the container. Reuses the zsh feature
    # (single cached compinit, enableGlobalCompInit off, defaultUserShell = zsh)
    # and wires homeModules.zsh into the container via its sharedModules.
    imports = [ self.nixosModules.zsh ];

    users.users.juliogm = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [
        "audio"
        "network"
        "pipewire"
        "video"
        "wheel"
      ];
      home = "/home/juliogm";
      createHome = true;
    };

    home-manager.users.juliogm = {
      imports = [ self.homeModules.user-juliogm ];
    };
  };
}
