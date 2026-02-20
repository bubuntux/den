let
  users = [
    "root"
    "@wheel"
  ];

  commonSettings = {
    warn-dirty = false;
    http-connections = 50;
    builders-use-substitutes = true;
    experimental-features = [
      "ca-derivations"
      "flakes"
      "nix-command"
      "pipe-operators"
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://den.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "den.cachix.org-1:1/SPrWvkgbW6kD/tfSN/a7WkoVajMEw1znID8ja+Z1M="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  commonGc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 28d";
  };
in
{
  flake.nixosModules.nix = _: {
    nixpkgs.config.allowUnfree = true;
    nix = {
      settings = commonSettings // {
        log-lines = 20;
        download-buffer-size = 268435456;
        auto-optimise-store = true;
        trusted-users = users;
        allowed-users = users;
      };
      gc = commonGc;
    };
  };

  flake.homeModules.nix =
    { pkgs, ... }:
    {
      nix.package = pkgs.nix;
      nixpkgs.config.allowUnfree = true;
      nix = {
        settings = commonSettings;
        gc = commonGc;
      };
    };
}
