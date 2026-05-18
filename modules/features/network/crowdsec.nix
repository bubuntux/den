{ self, ... }:
{
  flake.nixosModules.crowdsec =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Seed the writable console.yaml with the same default content the
      # upstream module would produce. Used by the tmpfiles rule below.
      consoleSeed =
        (pkgs.formats.yaml { }).generate "console.yaml"
          config.services.crowdsec.settings.console.configuration;
    in
    {
      imports = [ self.nixosModules.sops ];

      # Console enrollment key (optional). Add to secrets/appa.yaml:
      #
      #   crowdsec_console_key: "<from cscli console enroll on app.crowdsec.net>"
      #
      # An empty string is also fine — the systemd unit below skips
      # enrollment when the value is blank, so hosts without a Console
      # account can still build cleanly.
      sops.secrets.crowdsec_console_key = {
        sopsFile = "${self}/secrets/appa.yaml";
      };

      # Pin the service to the static `crowdsec` user (uid 993) and let
      # systemd pre-create /var/lib/crowdsec as a regular directory.
      #
      # The upstream NixOS module enables DynamicUser=true AND declares a
      # static User=crowdsec AND turns on PrivateUsers=true. Their combo
      # is broken: systemd allocates a transient UID for the parent state
      # dir while subdirs written by the static user keep uid 993,
      # splitting ownership across the tree. The setup pre-start fails
      # with EACCES and the service loops on Restart=. DynamicUser=false
      # unifies ownership; StateDirectory= ensures the dir exists by
      # activation time so pre-start has somewhere to write.
      systemd.services.crowdsec.serviceConfig = {
        DynamicUser = lib.mkForce false;
        StateDirectory = "crowdsec";
      };

      # Auto-heal a leftover symlink at /var/lib/crowdsec on first activation
      # after switching DynamicUser=true → false. systemd's migration moves
      # the data from /var/lib/private/<name> to /var/lib/<name> but doesn't
      # always remove the symlink at the public path. The symlink resolves
      # into /var/lib/private (700 root:root), blocking out-of-namespace
      # tools like interactive cscli. Idempotent — only acts when the
      # symlink + target combo is present.
      system.activationScripts.crowdsec-unwrap-statedir = ''
        if [ -L /var/lib/crowdsec ] && [ -d /var/lib/private/crowdsec ]; then
          rm /var/lib/crowdsec
          mv /var/lib/private/crowdsec /var/lib/crowdsec
        fi
      '';

      # cscli loads online_client.credentials_path on every invocation --
      # even the unrelated `cscli machines add` in the upstream setup script
      # crashes if the file is missing. Pre-create it as an empty file owned
      # by the crowdsec user so the daemon's startup path succeeds before
      # crowdsec-online-setup.service has had a chance to populate it.
      # cscli treats empty/login-less content as "no CAPI" with a warning
      # rather than a fatal error.
      #
      # console.yaml is similar but needs to be writable: `cscli console
      # enroll` rewrites it to record share_manual/tainted/context flags.
      # The upstream module points console_path at a /nix/store path which
      # is read-only, so enroll fails. Override the path and seed the file
      # once from the same default content the upstream module would have
      # generated. `C` copies only if the destination doesn't exist, so
      # cscli's later writes survive a `nixos-rebuild switch`.
      systemd.tmpfiles.rules = [
        "f /etc/crowdsec/online_api_credentials.yaml 0640 crowdsec crowdsec - "
        "C /etc/crowdsec/console.yaml 0640 crowdsec crowdsec - ${consoleSeed}"
      ];

      # The upstream NixOS module renders the daemon config to a /nix/store
      # path and passes it via `-c=<path>`, but raw cscli (used by upstream's
      # own crowdsec-firewall-bouncer-register) defaults to /etc/crowdsec/
      # config.yaml. Mirror the same content there so raw cscli works
      # without a wrapper. Generated from the merged settings tree, so it
      # always matches what the daemon sees.
      environment.etc."crowdsec/config.yaml".source =
        (pkgs.formats.yaml { }).generate "crowdsec-config.yaml"
          config.services.crowdsec.settings.general;

      # Map journalctl acquisitions' `labels.type` to `evt.Parsed.program`
      # so hub parsers whose filter is `evt.Parsed.program == '<name>'`
      # (e.g. LePresidente/jellyfin-logs) actually match. The syslog-logs
      # s00-raw parser sets `Parsed.program` from the syslog facility for
      # syslog-style sources, but journalctl acquisitions skip that path,
      # leaving Parsed.program empty and program-filtered hub parsers
      # silently inert (0% parse rate). Written as a flat environment.etc
      # file rather than via `localConfig.parsers.s00Raw` because the
      # upstream module renders localConfig entries to hash-named files
      # under /etc/crowdsec/parsers/ that aren't garbage-collected across
      # rebuilds, leaving stale duplicates and "multiple parsers named X"
      # warnings.
      environment.etc."crowdsec/parsers/s00-raw/journald-program.yaml".source =
        (pkgs.formats.yaml { }).generate "journald-program.yaml"
          {
            onsuccess = "next_stage";
            name = "den/journald-program";
            description = "Set Parsed.program from Labels.type for journalctl sources";
            filter = "evt.Line.Module == 'journalctl'";
            statics = [
              {
                meta = "program";
                expression = "evt.Line.Labels.type";
              }
            ];
          };

      # Whitelist trusted local networks so internal traffic never gets
      # banned, even if a misconfigured app triggers an HTTP scenario.
      # CIDRs sourced from `self.lib.lan` so SSH, Caddy, and CrowdSec
      # share one definition. Written via environment.etc (not
      # localConfig.parsers.s02Enrich) for the same stale-file reason
      # documented on the journald-program parser above.
      environment.etc."crowdsec/parsers/s02-enrich/lan-whitelist.yaml".source =
        (pkgs.formats.yaml { }).generate "lan-whitelist.yaml"
          {
            name = "den/lan-whitelist";
            description = "Trust local networks";
            whitelist = {
              reason = "trusted LAN ranges";
              ip = [
                "127.0.0.1"
                "::1"
              ];
              cidr = self.lib.lan.ipv4 ++ self.lib.lan.ipv6;
            };
          };

      services.crowdsec = {
        enable = true;
        # `cscli hub update` runs daily so parser / scenario / blocklist
        # definitions stay current.
        autoUpdateService = true;

        # The upstream module defaults api.server.enable=false; without this
        # the LAPI never binds and every bouncer can't connect. We want the
        # local agent + bouncers integration, so flip it on.
        settings.general.api.server.enable = true;

        # Where machine credentials get auto-generated by `cscli machine add
        # --auto` in the setup script (and read by the agent on every start).
        # Must be set when api.server.enable=true, otherwise the upstream
        # module's setup script null-derefs cfg.settings.lapi.credentialsFile.
        settings.lapi.credentialsFile = "/etc/crowdsec/local_api_credentials.yaml";

        # Tell the agent where the Central API (CAPI) credentials live and
        # enable community sharing + blocklist pull. We write the whole
        # online_client block here rather than via `settings.capi.credentialsFile`
        # because the upstream module's setup snippet for that option has
        # a stray `]` (`if ! grep ... ]; then`) that makes the check always
        # fail, which would re-run `cscli capi register` on every boot.
        # capi register is destructive (regenerates credentials, orphans
        # the old machine identity, and breaks any prior Console
        # association), so the buggy upstream loop is worse than not
        # registering at all. crowdsec-online-setup.service below does
        # the registration ourselves, exactly once.
        #
        # The full block is required because the upstream default for
        # online_client is `lib.mkDefault { ...full set... }`, which gets
        # replaced (not merged) when we set any nested field through the
        # format.type freeform schema.
        settings.general.api.server.online_client = {
          credentials_path = "/etc/crowdsec/online_api_credentials.yaml";
          sharing = true;
          pull = {
            community = true;
            blocklists = true;
          };
        };

        # CrowdSec's default API port (8080) collides with qbittorrent's
        # webuiPort. Pick 6868 instead -- 6060 is taken by the upstream-
        # defaulted Prometheus exporter, and we'd rather not move that.
        # Firewall and Caddy bouncers reference this port (see crowdsec-
        # bouncers.nix and reverse-proxy.nix).
        settings.general.api.server.listen_uri = "127.0.0.1:6868";

        # cscli console enroll writes to console_path to record which
        # Console feature flags (manual, tainted, context) are enabled.
        # Upstream defaults console_path to a /nix/store path which is
        # read-only; the tmpfiles rule above seeds a writable copy.
        settings.general.api.server.console_path = "/etc/crowdsec/console.yaml";

        # Generic collections that aren't tied to one specific service.
        # Per-service collections + acquisitions live in the service module
        # that produces the logs (see e.g. reverse-proxy.nix for caddy,
        # openssh.nix for sshd, jellyfin.nix / forgejo.nix / plex.nix for
        # their app-specific parsers).
        hub.collections = [
          "crowdsecurity/linux"
          "crowdsecurity/base-http-scenarios"
          "crowdsecurity/http-cve"
          "crowdsecurity/http-dos"
          "crowdsecurity/whitelist-good-actors"
        ];

      };

      # Registers the agent with the Central API and (optionally) enrolls
      # it with the CrowdSec Console webapp.
      #
      # Runs AFTER crowdsec.service (which tolerates an empty creds file
      # thanks to the tmpfiles entry above) and network-online.target (so
      # DNS works for api.crowdsec.net). Both cscli capi register and
      # cscli console enroll are gated on local idempotency markers
      # because:
      #   * `cscli capi register` is destructive -- it always generates
      #     fresh credentials, which would orphan the prior machine on
      #     api.crowdsec.net and break any existing Console enrollment.
      #     Gate on the presence of a password line in the credentials
      #     file.
      #   * `cscli console enroll` POSTs to app.crowdsec.net and the user
      #     has to validate the request in the webapp. Re-running it from
      #     the agent side after enrollment is pointless; gate on a
      #     touched marker file.
      #
      # After populating CAPI creds we reload crowdsec.service so the
      # daemon picks them up; otherwise the agent runs without community
      # blocklist data until next reboot.
      #
      # Empty `crowdsec_console_key` is fine -- CAPI registration still
      # happens (community blocklist), Console enrollment is skipped.
      systemd.services.crowdsec-online-setup = {
        description = "Register agent with the CrowdSec Central API + Console";
        after = [
          "crowdsec.service"
          "network-online.target"
        ];
        wants = [
          "crowdsec.service"
          "network-online.target"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ config.services.crowdsec.package ];
        script = ''
          creds=/etc/crowdsec/online_api_credentials.yaml
          did_register=0
          if [ ! -s "$creds" ] || ! grep -q '^password:' "$creds"; then
            echo "registering with the Central API..."
            cscli capi register --file "$creds"
            did_register=1
          fi

          if [ "$did_register" = 1 ]; then
            # The agent loaded the (empty) creds file at startup; force it
            # to re-read so the freshly-written CAPI credentials take effect.
            systemctl reload crowdsec.service || systemctl restart crowdsec.service
          fi

          key=$(cat ${config.sops.secrets.crowdsec_console_key.path})
          if [ -z "$key" ]; then
            echo "no console key configured; skipping Console enrollment"
            exit 0
          fi

          enrolled=/etc/crowdsec/.console-enrolled
          if [ -e "$enrolled" ]; then
            echo "already enrolled with the Console; skipping"
            exit 0
          fi

          cscli console enroll "$key"
          touch "$enrolled"
        '';
      };

      # In VM builds /etc is ephemeral -- each `nix run .#appa-vm` starts
      # from a fresh disk image, so the .console-enrolled marker doesn't
      # survive. Without this override, every VM cycle would POST a new
      # enrollment request to app.crowdsec.net, leaving a trail of pending
      # entries to clean up. Skip the Console step entirely in the VM and
      # keep just the CAPI registration so the community blocklist still
      # gets exercised during testing.
      virtualisation.vmVariant.systemd.services.crowdsec-online-setup.script = lib.mkForce ''
        creds=/etc/crowdsec/online_api_credentials.yaml
        if [ ! -s "$creds" ] || ! grep -q '^password:' "$creds"; then
          echo "registering with the Central API..."
          cscli capi register --file "$creds"
          systemctl reload crowdsec.service || systemctl restart crowdsec.service
        fi
        echo "VM build: skipping Console enrollment"
      '';
    };
}
