{ self, pkgs, ... }:
{
  flake.nixosModules.work = {
    imports = with self.nixosModules; [
      podman
    ];
  };

  flake.homeModules.work = {
    imports = with self.homeModules; [
    ];

    home = {
      sessionPath = [ "$HOME/.local/bin" ];
      shellAliases = {
        work = "distrobox enter -nw work";
        cvm = "distrobox enter -nw work -- ssh cvm";
        ben = "distrobox enter -nw work -- ssh ben";
      };
      # TODO: only in the pod?
      packages = with pkgs; [
        # cloudflare-warp
        google-chrome
        podman-compose
        slack
        # zoom-us
      ];
    };

    programs.distrobox = {
      enable = true;
      #   containers = {
      #     test = {
      #       pull = true;
      #       init = true;
      #       entry = false;
      #       unshare_netns = true;
      #       unshare_process = true;
      #       home = "/home/bbtux/test";
      #       image = "quay.io/toolbx/ubuntu-toolbox:24.04";
      #       additional_flags = "--hostname juliogm --network bridge -e TZ=America/Chicago";
      #     };
      #   };
    };

  };

}
