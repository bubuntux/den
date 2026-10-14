{
  self,
  inputs,
  lib,
  ...
}:
{
  # Home Manager module for user bbtux
  flake.modules = {
    homeManager.user-bbtux = {
      key = "den:homeManager.user-bbtux";
      # Git user configuration
      programs.git.settings.user = {
        name = "Julio Gutierrez";
        email = "413330+bubuntux@users.noreply.github.com";
      };

      # jj shares the same identity (mirrors the git config above)
      programs.jujutsu.settings.user = {
        name = "Julio Gutierrez";
        email = "413330+bubuntux@users.noreply.github.com";
      };

      # Sign own commits with the SSH key
      programs.jujutsu.settings.signing = {
        behavior = "own";
        backend = "ssh";
        key = "~/.ssh/id_ed25519.pub";
      };
    };

    # NixOS module for user bbtux
    nixos.user-bbtux =
      { config, ... }:
      let
        # Only add groups that exist on the system
        ifGroupExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
      in
      {
        key = "den:nixos.user-bbtux";
        users.users.bbtux = {
          isNormalUser = true;
          description = "Julio Guti";
          initialPassword = "bbtux";
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEfnT06gNHha8xJzYX7aFrszzdKraUp2Dv7iJvCNuBOE bbtux@zuko"
          ];
          extraGroups = ifGroupExist [
            "audio"
            "docker"
            "gamemode"
            "input"
            "libvirtd"
            "lpadmin"
            "lxd"
            "media"
            "network"
            "networkmanager"
            "pipewire"
            "plugdev"
            "podman"
            "video"
            "wheel"
          ];
        };

        home-manager.users.bbtux = {
          imports = [ self.modules.homeManager.user-bbtux ];
        };
      };
  };

  # Standalone Home Manager for any machine (scripts/bootstrap/): built with
  # --impure, since the account it lands on is whoever runs it. Pure evaluation
  # (CI) falls back to bbtux.
  flake.homeConfigurations = lib.listToAttrs (
    map
      (
        system:
        lib.nameValuePair "bbtux-anywhere-${system}" (
          inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = import inputs.nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
            modules = with self.modules.homeManager; [
              user-bbtux
              bundle-base
              profile-developer
              zsh
              nix
              (
                { lib, pkgs, ... }:
                let
                  envOr =
                    name: fallback:
                    let
                      value = builtins.getEnv name;
                    in
                    if value == "" then fallback else value;
                  username = envOr "USER" "bbtux";
                in
                {
                  home.username = username;
                  home.homeDirectory = envOr "HOME" (
                    if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${username}" else "/home/${username}"
                  );
                  targets.genericLinux.enable = pkgs.stdenv.hostPlatform.isLinux;
                  # The signing key lives on zuko, not on a borrowed machine.
                  programs.jujutsu.settings.signing = lib.mkForce { };
                }
              )
            ];
          }
        )
      )
      [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ]
  );
}
