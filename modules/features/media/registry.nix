{ self, ... }:
{
  # Boilerplate every media service repeats: media-group membership, umask,
  # mount dependencies, cgroup caps, the VM port forward and the .wg alias.
  # Modelled on services.reverse-proxy.routes -- each service declares its own
  # entry and neither side enumerates the other.
  #
  # It fills in the two mechanical route fields rather than wrapping
  # reverse-proxy.routes, so services keep declaring their own aliases and
  # tweaks. Anything genuinely service-specific stays in the service file.
  flake.modules.nixos.media-registry =
    { config, lib, ... }:
    let
      cfg = config.den.media.services;
      enabled = lib.attrValues cfg;
      # (name, service) pairs, for the bits that need the attribute name.
      named = lib.mapAttrsToList (name: service: { inherit name service; }) cfg;

      # Services running inside the VPN namespace are reachable at the namespace
      # address; host-side services are reachable at the bridge address. Getting
      # this backwards silently breaks name resolution across the boundary, which
      # is why it is derived here rather than hand-written per service.
      addressOf =
        s:
        let
          ns = config.vpnNamespaces.${s.namespace};
        in
        if s.inNamespace then ns.namespaceAddress else ns.bridgeAddress;
    in
    {
      key = "den:nixos.media-registry";

      options.den.media.services = lib.mkOption {
        default = { };
        description = ''
          Media services on this host. Each entry generates the shared plumbing
          described in this module's header.
        '';
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }:
            {
              options = {
                unit = lib.mkOption {
                  type = lib.types.str;
                  default = name;
                  description = ''
                    systemd unit to attach mounts and resource caps to, when it
                    differs from the attribute name (tvheadend runs as
                    `podman-tvheadend`, immich's web service is `immich-server`).
                  '';
                };

                user = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = name;
                  description = "Service user, or null when the service has none of its own.";
                };

                port = lib.mkOption {
                  type = lib.types.port;
                  description = "Primary HTTP port: proxied, and forwarded in the VM build.";
                };

                extraVmPorts = lib.mkOption {
                  type = lib.types.listOf lib.types.port;
                  default = [ ];
                  description = "Further ports to forward in the VM build only.";
                };

                mediaGroup = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = ''
                    Join the shared `media` group that owns /mnt/media. Services
                    keep declaring any other groups they need themselves.
                  '';
                };

                umask = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "0002";
                  description = ''
                    UMask override. 0002 keeps group-write on files the service
                    creates under /mnt/media, which is what lets the other
                    media-group services take over the files afterwards. Applied
                    with mkForce, since upstream units usually pin 0077/0022.
                  '';
                };

                requiresMounts = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ "/mnt/media" ];
                  description = ''
                    Paths that must be mounted before the unit starts. Without
                    this a service can start ahead of its disk and write into the
                    underlying root fs, which the later mount then shadows.
                  '';
                };

                resources = lib.mkOption {
                  default = null;
                  description = ''
                    cgroup caps for the unit, or null to leave them alone (immich
                    caps its whole slice instead). Percentages so they scale with
                    a hardware upgrade.
                  '';
                  type = lib.types.nullOr (
                    lib.types.submodule {
                      options = {
                        memoryHigh = lib.mkOption {
                          type = lib.types.str;
                          description = "Soft memory limit; the kernel throttles here.";
                        };
                        memoryMax = lib.mkOption {
                          type = lib.types.str;
                          description = "Hard memory limit; OOM-kill above this.";
                        };
                        cpuWeight = lib.mkOption {
                          type = lib.types.ints.positive;
                          description = ''
                            Relative CPU share under contention. 150 for anything
                            serving a live stream, 75 for the *arr scanners, 50
                            for bulk background work.
                          '';
                        };
                        ioWeight = lib.mkOption {
                          type = lib.types.ints.positive;
                          description = "Relative IO share; kept in step with cpuWeight.";
                        };
                        cpuQuota = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          example = "100%";
                          description = ''
                            Absolute CPU ceiling ("100%" is one core). Weight only
                            helps under contention, so a hard cap is the way to
                            stop a recheck or a backfill pinning every core.
                          '';
                        };
                      };
                    }
                  );
                };

                namespace = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "wg";
                  description = ''
                    VPN namespace this service is reachable across. Generates a
                    `<name>.wg` alias in /etc/hosts so services either side of the
                    boundary can dial it by name instead of a hardcoded address.
                    /etc/hosts is shared with the namespace because systemd's
                    NetworkNamespacePath switches only the net namespace.
                  '';
                };

                inNamespace = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = ''
                    Whether the service itself runs inside `namespace`. Selects
                    the namespace address rather than the bridge address for both
                    the alias and the proxy upstream -- VPN-Confinement only
                    installs PREROUTING DNAT, which never catches Caddy's
                    loopback traffic.
                  '';
                };

                proxy = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = ''
                    Register a reverse-proxy route. The service keeps declaring
                    its own aliases / public flag / rate limits; only `port` and
                    `upstreamAddr` come from here.
                  '';
                };
              };
            }
          )
        );
      };

      config = lib.mkIf (cfg != { }) {
        users.users = lib.mkMerge (
          map (s: { ${s.user}.extraGroups = [ "media" ]; }) (
            lib.filter (s: s.user != null && s.mediaGroup) enabled
          )
        );

        systemd.services = lib.mkMerge (
          map (s: {
            ${s.unit} = lib.mkMerge [
              (lib.mkIf (s.requiresMounts != [ ]) {
                unitConfig.RequiresMountsFor = s.requiresMounts;
              })
              (lib.mkIf (s.umask != null) {
                serviceConfig.UMask = lib.mkForce s.umask;
              })
              (lib.mkIf (s.resources != null) {
                serviceConfig = {
                  MemoryHigh = s.resources.memoryHigh;
                  MemoryMax = s.resources.memoryMax;
                  CPUWeight = s.resources.cpuWeight;
                  IOWeight = s.resources.ioWeight;
                }
                // lib.optionalAttrs (s.resources.cpuQuota != null) {
                  CPUQuota = s.resources.cpuQuota;
                };
              })
            ];
          }) enabled
        );

        # mkMerge rather than one attrset: several services share an address, and
        # networking.hosts concatenates the name lists per address.
        networking.hosts = lib.mkMerge (
          map ({ name, service }: { ${addressOf service} = [ "${name}.wg" ]; }) (
            lib.filter ({ service, ... }: service.namespace != null) named
          )
        );

        services.reverse-proxy.routes = lib.mkMerge (
          map (
            { name, service }:
            {
              ${name} = {
                inherit (service) port;
              }
              // lib.optionalAttrs service.inNamespace {
                upstreamAddr = config.vpnNamespaces.${service.namespace}.namespaceAddress;
              };
            }
          ) (lib.filter ({ service, ... }: service.proxy) named)
        );

        virtualisation.vmVariant.virtualisation.forwardPorts = lib.concatMap (
          s:
          map (p: {
            from = "host";
            host.port = p;
            guest.port = p;
          }) ([ s.port ] ++ s.extraVmPorts)
        ) enabled;
      };
    };
}
