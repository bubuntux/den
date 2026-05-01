{
  self,
  inputs,
  ...
}:
{
  # Home Manager module for user juliogm
  flake.homeModules.user-juliogm =
    { pkgs, lib, ... }:
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
        gws
        taskwarrior
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

      # Language servers Helix auto-detects when their binaries are on PATH.
      # Docker LSPs are already provided by the shared helix module.
      programs.helix.extraPackages = with pkgs; [
        kotlin-language-server
        jdt-language-server
        terraform-ls
        pyright
        ruff
      ];

      # Git user configuration (decrypted from sops secret via bind mount)
      programs.git.includes = [ { path = "/run/secrets-host/git_config"; } ];

      # SSH host configuration (decrypted from sops secret via bind mount)
      programs.ssh.includes = [ "/run/secrets-host/ssh_config" ];

      programs.bash.initExtra = ''
        for f in "$HOME"/.*-kube-profile; do
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
          sops.secrets.ssh_config.sopsFile = "${self}/secrets/juliogm.yaml";
          programs.git.includes = lib.mkForce [
            { path = config.sops.secrets.git_config.path; }
          ];
          programs.ssh.includes = lib.mkForce [
            config.sops.secrets.ssh_config.path
          ];

        }
      )
    ];
  };

  # NixOS module for user juliogm (used inside the work container)
  flake.nixosModules.user-juliogm = _: {
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
