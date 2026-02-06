let
  users = [
    "root"
    "@wheel"
  ];
in
{
  flake.nixosModules.nix = {
    nixpkgs.config.allowUnfree = true;
    nix = {
      settings = {
        log-lines = 20;
        warn-dirty = false;
        http-connections = 50;
        download-buffer-size = 268435456;
        auto-optimise-store = true;
        builders-use-substitutes = true;
        trusted-users = users;
        allowed-users = users;
        experimental-features = [
          "ca-derivations"
          "flakes"
          "nix-command"
          "pipe-operators"
        ];
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
        ];
        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 4w";
      };
    };
  };
}
