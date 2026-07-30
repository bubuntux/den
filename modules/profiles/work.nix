{ self, ... }:
{
  flake.modules.nixos.profile-work = {
    key = "den:nixos.profile-work";
    imports = with self.modules.nixos; [
      wifi-work
      work-container
    ];
  };
}
