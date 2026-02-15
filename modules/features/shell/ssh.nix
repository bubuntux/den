{
  flake.homeModules.ssh = {
    programs.ssh = {
      enable = true;
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
  };
}
