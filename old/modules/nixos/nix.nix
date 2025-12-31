let
  users = [
    "root"
    "@wheel"
  ];
in
{
  nix = {
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
        "https://hyprland.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 4w";
    };
  };
}
