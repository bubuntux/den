{ self, ... }:
{
  flake.modules.nixos.syncthing =
    { config, ... }:
    let
      guiPort = 8384;
      dataDir = "/mnt/data/syncthing";
    in
    {
      key = "den:nixos.syncthing";
      imports = [ self.modules.nixos.sops ];

      sops.secrets.syncthing_gui_password = {
        sopsFile = "${self}/secrets/appa.yaml";
        owner = "syncthing";
      };

      services.syncthing = {
        enable = true;
        # Identity, keys and the synced folders on /mnt/data so restic covers
        # them; the database is rewritten on every rescan and stays on the SSD.
        inherit dataDir;
        databaseDir = "/var/lib/syncthing";
        openDefaultPorts = true;

        guiAddress = "127.0.0.1:${toString guiPort}";
        guiPasswordFile = config.sops.secrets.syncthing_gui_password.path;

        overrideDevices = true;
        overrideFolders = true;

        settings = {
          gui = {
            user = "bbtux";
            # Syncthing refuses a Host header that isn't localhost while the GUI
            # is on loopback, which is every request Caddy forwards.
            insecureSkipHostcheck = true;
          };

          options = {
            # Both ends are on the LAN, so nothing here needs the outside:
            # no discovery server, no relay pool, and natEnabled off takes
            # UPnP and the STUN probes with it. Broadcast discovery on
            # 21027 is what finds batocera.
            globalAnnounceEnabled = false;
            relaysEnabled = false;
            natEnabled = false;
            # Usage reporting: -1 is "declined", 0 is undecided and prompts.
            urAccepted = -1;
          };

          devices.batocera = {
            id = "2BPJCX3-PMRJSHV-E4VSGRK-443WTP6-X2N2APY-37JMYKN-54AMJKX-UERMQQR";
            # Discovery first, then the DHCP hostname the router serves --
            # bare, since `batocera.local` does not resolve here.
            addresses = [
              "dynamic"
              "tcp://batocera:22000"
            ];
          };

          folders."${dataDir}/batocera-saves" = {
            id = "4neqj-7bexg";
            label = "batocera saves";
            devices = [ "batocera" ];
            versioning = {
              type = "trashcan";
              params.cleanoutDays = "30";
            };
          };
        };
      };

      services.reverse-proxy.routes.syncthing = {
        port = guiPort;
        aliases = [ "sync" ];
      };

      systemd.services.syncthing = {
        unitConfig.RequiresMountsFor = [ "/mnt/data" ];
        serviceConfig = {
          # databaseDir sits outside dataDir, so the module's createHome does
          # not reach it and syncthing cannot mkdir under /var/lib itself.
          StateDirectory = "syncthing";
          StateDirectoryMode = "0700";
          # Bulk background work that yields to streams, so qbittorrent's tier;
          # one core so a rescan can't team up with an immich backfill.
          MemoryHigh = "8%";
          MemoryMax = "15%";
          CPUWeight = 50;
          IOWeight = 50;
          CPUQuota = "100%";
        };
      };

      virtualisation.vmVariant.virtualisation.forwardPorts = [
        {
          from = "host";
          host.port = guiPort;
          guest.port = guiPort;
        }
      ];
    };
}
