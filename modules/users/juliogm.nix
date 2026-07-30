{
  self,
  inputs,
  ...
}:
{
  flake.modules = {
    # Home Manager module for user juliogm
    homeManager.user-juliogm =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        jsonFormat = pkgs.formats.json { };
        claudeBaseSettings = import "${self}/modules/features/dev-tools/_claude-settings.nix" { };
        settingsFile = jsonFormat.generate "claude-base-settings.json" (
          claudeBaseSettings // { "$schema" = "https://json.schemastore.org/claude-code-settings.json"; }
        );
      in
      {
        key = "den:homeManager.user-juliogm";
        imports = with self.modules.homeManager; [
          profile-developer
          aws
          glab
          gws
          xdg
        ];

        # No desktop icons for this user (work container / standalone), so skip
        # the Desktop folder by pointing it at $HOME (same trick as the Sway
        # bundle). Avoids xdg.userDirs.createDirectories making a stray ~/Desktop.
        xdg.userDirs.desktop = config.home.homeDirectory;

        # Prevent HM from managing settings.json as a read-only symlink,
        # so Claude Code plugins can write to it imperatively.
        programs.claude-code.settings = lib.mkForce { };

        # Write Nix-defined settings as a mutable file, merging with any
        # existing imperative changes (plugins, etc.) on each activation.
        #
        # jq's `*` gives precedence to its right operand, so the Nix base goes
        # last: keys this module defines are reasserted on every activation,
        # while imperative top-level keys it doesn't define (plugin state,
        # onboarding flags) survive. With the operands the other way round the
        # on-disk file wins and no edit to _claude-settings.nix ever reaches this
        # user again. Note `*` replaces arrays rather than concatenating, which
        # is what we want for permissions: Nix owns the policy, and Claude Code
        # records per-project "don't ask again" grants in that project's
        # .claude/settings.local.json rather than here.
        home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          target="$HOME/.claude/settings.json"
          mkdir -p "$HOME/.claude"
          if [ -f "$target" ] && [ ! -L "$target" ]; then
            ${pkgs.jq}/bin/jq -s '.[1] * .[0]' \
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

    # NixOS module for user juliogm (used inside the work container)
    nixos.user-juliogm = {
      key = "den:nixos.user-juliogm";
      # zsh as juliogm's login shell inside the container. Reuses the zsh feature
      # (single cached compinit, enableGlobalCompInit off, defaultUserShell = zsh)
      # and wires homeModules.zsh into the container via its sharedModules.
      imports = [ self.modules.nixos.zsh ];

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
        imports = [ self.modules.homeManager.user-juliogm ];
      };
    };
  };

  # Standalone Home Manager configuration for non-NixOS systems
  flake.homeConfigurations.juliogm = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    modules = [
      self.modules.homeManager.user-juliogm
      self.modules.homeManager.zsh
      self.modules.homeManager.nix
      self.modules.homeManager.sops
      self.modules.homeManager.auto-upgrade
      (
        { config, lib, ... }:
        {
          home.username = "juliogm";
          home.homeDirectory = "/home/juliogm";
          targets.genericLinux.enable = true;

          # Standalone (non-NixOS) juliogm uses zsh exclusively, so opt out of
          # the bash config that bundle-base enables for every user. The work
          # container keeps bash (it may be needed there), so this override
          # lives here rather than in the shared user-juliogm home module.
          programs.bash.enable = lib.mkForce false;

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

}
