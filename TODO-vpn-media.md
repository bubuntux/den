# VPN Media Setup TODOs

## ProtonVPN WireGuard Configuration

Update `modules/profiles/nas.nix` with real ProtonVPN values from
ProtonVPN → Downloads → WireGuard configuration:

- [ ] `wgAddress` — ProtonVPN assigned WireGuard address (e.g. `10.2.0.2/32`)
- [ ] `wgDns` — ProtonVPN DNS servers (e.g. `["10.2.0.1"]`)
- [ ] `wgPeerPublicKey` — ProtonVPN server public key
- [ ] `wgPeerEndpoint` — ProtonVPN server endpoint (`host:port`)

## Secrets

- [ ] Edit `secrets/appa.yaml` with `sops secrets/appa.yaml` and set the real `wireguard_private_key`

## .sops.yaml

- [ ] Get appa's age key: run `ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub` on appa
- [ ] Add the key as `&appa` in `.sops.yaml` and uncomment `# - *appa` in the appa creation rule
- [ ] Re-encrypt appa secrets: `sops updatekeys secrets/appa.yaml`

## Validation

After filling in real values:

- [ ] `nix flake check`
- [ ] Deploy to appa: `sudo nixos-rebuild switch --flake .`
- [ ] `sudo machinectl list` → shows `vpn-media`
- [ ] `sudo nixos-container run vpn-media -- wg show` → WG interface active
- [ ] `ping 10.200.200.2` → container reachable
- [ ] `sudo nixos-container run vpn-media -- curl https://ifconfig.me` → ProtonVPN IP
- [ ] `curl http://<appa-ip>:8080` → qBittorrent web UI
- [ ] `curl http://<appa-ip>:9696` → Prowlarr web UI
- [ ] Stop WG inside container → verify no internet (kill switch works)
