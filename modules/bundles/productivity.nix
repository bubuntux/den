{
  flake.nixosModules.bundle-productivity =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        kdePackages.okular # Powerful PDF viewer
        qalculate-gtk # Versatile calculator
      ];
    };
}
