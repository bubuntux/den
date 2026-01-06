{ ... }:
let
  users = [
    "root"
    "@wheel"
  ];
in
{
  den.default.includes = [
    {
      nixos.nix = {
        optimise.automatic = true;
        settings = {
          log-lines = 20;
          warn-dirty = false;
          http-connections = 50;
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
          interval = "weekly";
          options = "--delete-older-than 7d";
        };
      };
    }
  ];
}
