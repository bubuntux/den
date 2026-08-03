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
      profile-gaming
      inputs.nixos-hardware.nixosModules.common-cpu-amd
      inputs.nixos-hardware.nixosModules.common-gpu-amd
    ];

    networking.hostName = "katara";
    system.stateVersion = "25.11";

    # GDM because this machine is shared: a graphical user list and session
    # picker, and it remembers each user's last session in accountsservice, so
    # shari stays in GNOME and bbtux in Sway. No defaultSession on purpose --
    # under GDM it wipes that memory every boot (see CLAUDE.md).
    den.desktop.loginManager = "gdm";
  };
}
