{ self, ... }:
{
  # Shared family machine: a browser, a desktop per person, and nothing else.
  # Deliberately no developer, work or gaming capability -- a host that wants
  # those imports them as well (katara does).
  #
  # Only the *additive* desktop settings live here (`environments`, `users`).
  # loginManager, defaultSession and autoLogin are single-valued whole-machine
  # policy and belong to the host: a machine importing this alongside another
  # role cannot have two profiles each naming its own greeter.
  flake.modules.nixos.profile-family = {
    key = "den:nixos.profile-family";
    imports = with self.modules.nixos; [
      user-shari
      user-bbtux
      bundle-desktop
      firefox
      # Kept on purpose: a machine somebody else uses is the one you most need
      # to reach remotely to fix or reconfigure without taking it away from them.
      openssh
    ];

    den.desktop = {
      environments = [
        "gnome"
        "sway"
      ];
      users = {
        shari = "gnome";
        bbtux = "sway";
      };
    };
  };
}
