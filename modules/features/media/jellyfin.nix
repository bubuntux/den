{
  flake.nixosModules.jellyfin =
    _:
    # Upstream services.jellyfin module has no port option; these are the
    # hard-coded HTTP/HTTPS ports baked into the Jellyfin binary.
    let
      port = 8096;
      httpsPort = 8920;
    in
    {
      services.jellyfin = {
        enable = true;
        openFirewall = true;
      };

      # `render` owns /dev/dri/renderD128 (GPU compute / VA-API), `video` owns
      # the legacy card0 node. Jellyfin's hwaccel probe checks group membership
      # before opening the device even when the device perms would already
      # permit access, so without these groups the encoder silently falls back
      # to software transcoding -- which on a Pentium Silver pegs the CPU
      # during trickplay / chapter image generation.
      users.users.jellyfin.extraGroups = [
        "media"
        "render"
        "video"
      ];

      # Library scans / playback all hit /mnt/media; defer start until
      # the disk mounts so Jellyfin doesn't index an empty mountpoint.
      systemd.services.jellyfin.unitConfig.RequiresMountsFor = [ "/mnt/media" ];

      # Resource caps (percent-of-RAM scales with hardware upgrades).
      # Transcoding sessions can burst memory; cap above observed ~700 MB
      # peak so live streams don't get OOM-killed mid-playback.
      # CPUWeight=150 (default 100) wins CPU contention over scanners and
      # downloaders — real-time playback timing must beat bulk work.
      systemd.services.jellyfin.serviceConfig = {
        MemoryHigh = "8%";
        MemoryMax = "15%";
        CPUWeight = 150;
      };

      # Catches actual auth failures from Jellyfin's own log stream — slow
      # brute force that stays below caddy-ratelimit wouldn't otherwise
      # trigger anything.
      services.crowdsec.hub.collections = [ "LePresidente/jellyfin" ];
      services.crowdsec.localConfig.acquisitions = [
        {
          source = "journalctl";
          journalctl_filter = [ "_SYSTEMD_UNIT=jellyfin.service" ];
          labels.type = "jellyfin";
        }
      ];

      services.reverse-proxy.routes.jellyfin = {
        inherit port;
        aliases = [
          "jf"
          "media"
        ];
        public = true;
        # Rate-limit the login endpoint (5/IP/min defaults). Synchronous
        # check, independent of CrowdSec's log-based scenarios.
        rateLimit.paths = [ "/Users/AuthenticateByName" ];
        # Disable response buffering so streaming starts responding to the
        # client immediately (matters for video seek / first-frame latency).
        proxyConfig = ''
          flush_interval -1
        '';
      };

      virtualisation.vmVariant.virtualisation = {
        # Jellyfin 10.10+ refuses to start with <2 GiB free at its data dir.
        # In production the data lives on /mnt/data; in the VM it falls back to /.
        diskSize = 4096;

        forwardPorts = [
          {
            from = "host";
            host.port = port;
            guest.port = port;
          }
          {
            from = "host";
            host.port = httpsPort;
            guest.port = httpsPort;
          }
        ];
      };
    };
}
