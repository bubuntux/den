{ lib, ... }:
{
  # flake-parts declares no option for `flake.lib`, which leaves it a *unique*
  # option: the whole repo gets exactly one definition of it, and the second
  # file to reach for a shared constant fails with "defined multiple times ...
  # No option has been declared for this flake output attribute". That made the
  # "shared constants are plain values" convention a one-file privilege --
  # features/system/networking.nix spent it on `flake.lib.lan`.
  #
  # Declaring it as an attrset lets every module contribute its own key, read
  # back as `self.lib.<name>` from anywhere. (flake-parts' mkSubmoduleOptions
  # wrapper is the older way to do this; it has been deprecated since Nixpkgs
  # 22.05 made a direct `options.flake.<name>` declaration work.)
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = ''
      Repo-wide constants and helpers, contributed per file and exposed on the
      flake as `self.lib.<name>`. For values that several modules must agree on
      but that are not a per-host variant point, and so would not earn a NixOS
      option.
    '';
  };
}
