# VPN Media Setup TODOs

## ProtonVPN WireGuard Configuration

Update `modules/profiles/nas.nix` with real ProtonVPN values from
ProtonVPN → Downloads → WireGuard configuration:

- [ ] `wgAddress` — ProtonVPN assigned WireGuard address (e.g. `10.2.0.2/32`)
- [ ] `wgDns` — ProtonVPN DNS servers (e.g. `["10.2.0.1"]`)
- [ ] `wgPeerPublicKey` — ProtonVPN server public key
- [ ] `wgPeerEndpoint` — ProtonVPN server endpoint (`host:port`)

## Secrets

- [ ] Create a sops secrets file for the NAS host and add the `wireguard_private_key`
- [ ] Add the host's age key to `.sops.yaml` and create a creation rule for its secrets file
- [ ] Uncomment `sops.secrets.wireguard_private_key` and `wgPrivateKeyFile` in `modules/profiles/nas.nix`

## Validation

After filling in real values:

- [ ] `nix flake check`
- [ ] Deploy to NAS host: `sudo nixos-rebuild switch --flake .`
- [ ] `sudo machinectl list` → shows `vpn-media`
- [ ] `sudo nixos-container run vpn-media -- wg show` → WG interface active
- [ ] `ping 10.200.200.2` → container reachable
- [ ] `sudo nixos-container run vpn-media -- curl https://ifconfig.me` → ProtonVPN IP
- [ ] `curl http://<nas-ip>:8080` → qBittorrent web UI
- [ ] `curl http://<nas-ip>:9696` → Prowlarr web UI
- [ ] Stop WG inside container → verify no internet (kill switch works)
