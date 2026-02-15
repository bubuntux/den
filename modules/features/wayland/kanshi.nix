{
  self,
  ...
}:
{
  # Home Manager module for kanshi display management
  flake.homeModules.kanshi = {
    services.kanshi = {
      enable = true;

      settings = [
        # Output definitions
        {
          output = {
            criteria = "eDP-1";
            status = "enable";
            mode = "1920x1200";
            position = "0,0";
          };
        }
        {
          output = {
            criteria = "DP-3";
            status = "enable";
            mode = "2560x1440";
          };
        }
        {
          output = {
            criteria = "DP-4";
            status = "enable";
            mode = "2560x1440";
          };
        }
        {
          output = {
            criteria = "DP-5";
            status = "enable";
            mode = "2560x1440";
            transform = "270";
          };
        }
        {
          output = {
            criteria = "DP-6";
            status = "enable";
            mode = "2560x1440";
            transform = "270";
          };
        }
        {
          output = {
            criteria = "DP-7";
            status = "enable";
            mode = "2560x1440";
          };
        }
        {
          output = {
            criteria = "DP-8";
            status = "enable";
            mode = "2560x1440";
          };
        }
        {
          output = {
            criteria = "DP-9";
            status = "enable";
            mode = "2560x1440";
          };
        }

        # Profiles
        {
          profile.name = "laptop";
          profile.outputs = [ { criteria = "eDP-1"; } ];
        }
        {
          profile.name = "office";
          profile.outputs = [
            {
              criteria = "DP-3";
              position = "0,0";
            }
            {
              criteria = "DP-4";
              position = "2560,0";
            }
            {
              criteria = "eDP-1";
              position = "1440,1440";
            }
          ];
        }
        {
          profile.name = "workstation5-7";
          profile.outputs = [
            {
              criteria = "DP-5";
              position = "0,0";
            }
            {
              criteria = "DP-7";
              position = "1440,0";
            }
            {
              criteria = "eDP-1";
              position = "1440,1440";
            }
          ];
        }
        {
          profile.name = "workstation6-8";
          profile.outputs = [
            {
              criteria = "DP-6";
              position = "0,0";
            }
            {
              criteria = "DP-8";
              position = "1440,0";
            }
            {
              criteria = "eDP-1";
              position = "1440,1440";
            }
          ];
        }
        {
          profile.name = "workstation6-9";
          profile.outputs = [
            {
              criteria = "DP-6";
              position = "0,0";
            }
            {
              criteria = "DP-9";
              position = "1440,0";
            }
            {
              criteria = "eDP-1";
              position = "1440,1440";
            }
          ];
        }
      ];
    };
  };

  # NixOS module that includes kanshi home module
  flake.nixosModules.kanshi =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.kanshi ];
    };
}
