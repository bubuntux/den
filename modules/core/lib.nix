{ lib, ... }:
{
  # Undeclared, `flake.lib` is a unique option: the second file to reach for a
  # shared constant fails with "defined multiple times". Declaring it as an
  # attrset lets every module contribute a key, read back as `self.lib.<name>`.
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
