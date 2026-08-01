{ self, ... }:
{
  flake.modules.nixos.crowdsec =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Same default content the upstream module would produce; the tmpfiles
      # rule below seeds a writable copy from it.
      consoleSeed =
        (pkgs.formats.yaml { }).generate "console.yaml"
          config.services.crowdsec.settings.console.configuration;
    in
    {
      key = "den:nixos.crowdsec";
      imports = [ self.modules.nixos.sops ];

      # Optional; blank is fine, the unit below skips enrollment then.
      sops.secrets.crowdsec_console_key = {
        sopsFile = "${self}/secrets/appa.yaml";
      };

      # Upstream combines DynamicUser with a static User= and PrivateUsers,
      # which splits ownership of the state dir between a transient uid and
      # 993: pre-start fails EACCES and the service loops on Restart=.
      systemd.services.crowdsec.serviceConfig = {
        DynamicUser = lib.mkForce false;
        StateDirectory = "crowdsec";
        # Upstream sets no ExecReload, so `systemctl reload` exits
        # NOTIMPLEMENTED; the daemon takes SIGHUP as a config/hub reload.
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";

        # Steady state is ~290 MB; the weights keep bouncer decisions timely
        # while heavy *arr scans run.
        MemoryHigh = "4%";
        MemoryMax = "8%";
        CPUWeight = 125;
        IOWeight = 125;
      };

      # `+` runs just this step as root: the unit's DynamicUser cannot manage
      # system units, so the reload ended 4/NOPERMISSION.
      systemd.services.crowdsec-update-hub.serviceConfig.ExecStartPost = lib.mkForce [
        "+${pkgs.systemd}/bin/systemctl reload crowdsec.service"
      ];

      # systemd's DynamicUser migration leaves a symlink into /var/lib/private
      # (700 root:root), which blocks interactive cscli. Idempotent.
      system.activationScripts.crowdsec-unwrap-statedir = ''
        if [ -L /var/lib/crowdsec ] && [ -d /var/lib/private/crowdsec ]; then
          rm /var/lib/crowdsec
          mv /var/lib/private/crowdsec /var/lib/crowdsec
        fi
      '';

      # cscli loads the credentials file on every invocation and crashes if it
      # is missing; empty reads as "no CAPI" with a warning. console.yaml must
      # be writable (enroll rewrites it) and upstream points it at the store,
      # so `C` seeds it once and cscli's writes survive a rebuild.
      systemd.tmpfiles.rules = [
        "f /etc/crowdsec/online_api_credentials.yaml 0640 crowdsec crowdsec - "
        "C /etc/crowdsec/console.yaml 0640 crowdsec crowdsec - ${consoleSeed}"
      ];

      # Upstream passes the daemon `-c=<store path>`, but raw cscli reads
      # /etc/crowdsec/config.yaml. Same merged settings, so they cannot drift.
      environment.etc."crowdsec/config.yaml".source =
        (pkgs.formats.yaml { }).generate "crowdsec-config.yaml"
          config.services.crowdsec.settings.general;

      # journalctl acquisitions never set Parsed.program, so hub parsers that
      # filter on it sit at a 0% parse rate. Written as a flat environment.etc
      # file because localConfig renders hash-named files that are never
      # collected, leaving "multiple parsers named X" after a few rebuilds.
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

      # So a misconfigured app cannot get the LAN banned. CIDRs from
      # self.lib.lan; environment.etc for the same reason as above.
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
        autoUpdateService = true;

        # Off upstream, so the LAPI never binds and no bouncer can connect.
        settings.general.api.server.enable = true;

        # Required once api.server.enable is on, or upstream's setup script
        # null-derefs it.
        settings.lapi.credentialsFile = "/etc/crowdsec/local_api_credentials.yaml";

        # Written out in full rather than through settings.capi.credentialsFile:
        # upstream's setup snippet for that option has a stray `]` that makes its
        # guard always fail, re-running the destructive `capi register` every
        # boot. crowdsec-online-setup below does it once instead. The whole block
        # is needed because the upstream mkDefault is replaced, not merged.
        settings.general.api.server.online_client = {
          credentials_path = "/etc/crowdsec/online_api_credentials.yaml";
          sharing = true;
          pull = {
            community = true;
            blocklists = true;
          };
        };

        # 8080 collides with qbittorrent, 6060 with the Prometheus exporter.
        # crowdsec-bouncers.nix and reverse-proxy.nix reference this port.
        settings.general.api.server.listen_uri = "127.0.0.1:6868";

        # Upstream points this at the store, which enroll cannot write.
        settings.general.api.server.console_path = "/etc/crowdsec/console.yaml";

        # Generic only; per-service collections live with the service that
        # produces the logs.
        hub.collections = [
          "crowdsecurity/linux"
          "crowdsecurity/base-http-scenarios"
          "crowdsecurity/http-cve"
          "crowdsecurity/http-dos"
          "crowdsecurity/whitelist-good-actors"
        ];

      };

      # Both steps are gated on local markers and must stay that way: `capi
      # register` is destructive (fresh credentials orphan the machine on
      # api.crowdsec.net), and `console enroll` POSTs a request a human then
      # validates in the webapp.
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

      # /etc is ephemeral in the VM, so the enrolled marker never survives and
      # every run would leave a pending request on app.crowdsec.net.
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
