{
  inputs,
  self,
  ...
}:
{
  flake.nixosConfigurations.katara = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit self inputs; };
    system = "x86_64-linux";
    modules = [ self.modules.nixos.katara ];
  };

  # Host identity and the roles it plays. Hardware and display layout are
  # separate fragments of this same module name (hardware.nix, monitors.nix) --
  # flake.modules merges them into one imports list, so each fragment gets its
  # own `key`.
  flake.modules.nixos.katara = {
    key = "den:nixos.katara#host";
    # Two roles: the family desktop it is for, and the workstation stack it also
    # carries. Their additive desktop settings merge, so the machine installs
    # both GNOME and Sway and every user gets the environment named for them.
    imports = with self.modules.nixos; [
      profile-family
      profile-workstation
      inputs.nixos-hardware.nixosModules.common-cpu-amd
      inputs.nixos-hardware.nixosModules.common-gpu-amd
    ];

    networking.hostName = "katara";
    system.stateVersion = "25.11";

    # Whole-machine desktop policy: one greeter for two roles. GDM rather than
    # greetd because this machine is shared -- it presents a graphical user list
    # and session picker instead of a keyboard-only TUI, and it remembers each
    # user's last session afterwards. That memory is accountsservice state in
    # /var/lib/AccountsService/users/<name>, not configuration: every user's
    # *first* login uses defaultSession below, so bbtux -- whose
    # den.desktop.users entry is sway -- starts in GNOME until he picks Sway
    # once from the session menu. Keyring auto-unlock still works: GDM derives
    # its PAM config from security.pam.services.login.enableGnomeKeyring, which
    # the sway session module sets.
    den.desktop.loginManager = "gdm";
    services.displayManager.defaultSession = "gnome";
  };
}
