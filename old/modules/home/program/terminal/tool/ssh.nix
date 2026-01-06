{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # package= pkgs.openssh_hpn;

    matchBlocks = {
      "bbtux" = {
        port = 31988;
        user = "core";
        hostname = "i4.bbtux.com";
        host = "*bbtux.com";
      };

      "appa" = {
        host = "appa";
        hostname = "192.168.0.2";
        user = "core";
      };
    };
  };
}
