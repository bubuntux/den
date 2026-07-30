{
  flake.modules.nixos.nix-ld = {
    key = "den:nixos.nix-ld";
    programs.nix-ld.enable = true;
  };
}
