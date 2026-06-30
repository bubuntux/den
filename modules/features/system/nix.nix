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
      "https://devenv.cachix.org"
      "https://nix-community.cachix.org"
      "https://helix.cachix.org"
    ];
    extra-trusted-public-keys = [
      "den.cachix.org-1:1/SPrWvkgbW6kD/tfSN/a7WkoVajMEw1znID8ja+Z1M="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr+cv0M+/mB6Sto4="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
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
    # pnpm 10.29.2 is flagged insecure but is only a hermetic build-time dep of
    # the gws (googleworkspace/cli) flake package; no runtime exposure.
    nixpkgs.config.permittedInsecurePackages = [ "pnpm-10.29.2" ];
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

      # Allow unfree packages for ad-hoc nix commands (nix-shell, nix-env, etc.)
      xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";
    };
}
