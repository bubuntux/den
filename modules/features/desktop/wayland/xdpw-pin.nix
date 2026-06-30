{ inputs, ... }:
{
  # Pin xdg-desktop-portal-wlr to 0.8.2.
  #
  # On 2026-06-23 a `flake.lock` update bumped this package from 0.8.2 to an
  # unreleased 0.8.3 git snapshot (upstream's latest *tagged* release is only
  # 0.8.1). 0.8.3 regressed screencast: the PipeWire source node stays in the
  # "running" state but stops pushing frames (RATE -> 0), so screen shares
  # freeze after a few minutes — reproduced from Chrome in the work container,
  # on any monitor, on AC or battery. Verified that the 0.8.2 build is solid by
  # running it by hand against the live session.
  #
  # Pinned to the exact nixpkgs commit that shipped the 0.8.2 build we tested,
  # so the result is byte-for-byte what was validated. The rev is fixed (not a
  # branch), so `nix flake update` leaves it alone.
  #
  # TODO: drop this module (and the input) once a fixed release (> 0.8.3) lands.
  # Tracking: https://github.com/emersion/xdg-desktop-portal-wlr/issues/81
  flake-file.inputs.nixpkgs-xdpw-pin.url = "github:NixOS/nixpkgs/3e41b24abd260e8f71dbe2f5737d24122f972158";

  flake.nixosModules.xdpw-pin = _: {
    nixpkgs.overlays = [
      (_: prev: {
        inherit (inputs.nixpkgs-xdpw-pin.legacyPackages.${prev.stdenv.hostPlatform.system})
          xdg-desktop-portal-wlr
          ;
      })
    ];
  };
}
