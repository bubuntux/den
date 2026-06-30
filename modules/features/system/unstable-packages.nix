{ inputs, ... }:
{
  # Cherry-pick a few fast-moving leaf apps from nixpkgs-unstable onto the
  # otherwise-stable (nixos-26.05) hosts. These lag noticeably on the frozen
  # stable channel and aren't security-backported the way browsers are, so we
  # track them from unstable via an overlay. Browsers are deliberately NOT here
  # — stable backports keep firefox/chrome current (stable firefox can even be
  # newer than unstable).
  #
  # Imported per-evaluation: the sway host (zuko) for claude-code/devenv, and
  # the work container for slack/jetbrains.gateway (a host overlay does not
  # cross the nspawn boundary, so the container imports this module too).
  flake.nixosModules.unstable-packages = _: {
    nixpkgs.overlays = [
      (
        _: prev:
        let
          unstable = import inputs.nixpkgs-unstable {
            inherit (prev.stdenv.hostPlatform) system;
            config.allowUnfree = true; # slack, jetbrains.gateway are unfree
          };
        in
        {
          inherit (unstable)
            slack
            claude-code
            devenv
            ;
          # Nested set: keep the rest of jetbrains on the host channel, swap
          # only gateway so the work container's remote-IDE client stays current.
          jetbrains = prev.jetbrains // {
            inherit (unstable.jetbrains) gateway;
          };
        }
      )
    ];
  };
}
