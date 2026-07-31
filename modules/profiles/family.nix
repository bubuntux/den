{ self, ... }:
{
  # Shared family machine: a browser, a desktop for each way of working, and
  # nothing else. Deliberately no developer, work or gaming capability -- a host
  # that wants those imports them as well (katara does).
  #
  # Only the *additive* desktop setting lives here (`environments`).
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

    # Both desktops are installed and every user gets both configured, so the
    # choice is made at the greeter rather than here: shari stays in GNOME,
    # bbtux picks Sway, and neither is locked out of the other.
    den.desktop.environments = [
      "gnome"
      "sway"
    ];
  };
}
