{
  flake.modules.nixos.dirty-frag-mitigation = {
    key = "den:nixos.dirty-frag-mitigation";
    # CVE-2026-43284 (esp4/esp6) and CVE-2026-43500 (rxrpc).
    # Safe to blacklist: no IPsec or AFS in this configuration (VPNs use WireGuard).
    boot.blacklistedKernelModules = [
      "esp4"
      "esp6"
      "rxrpc"
    ];
  };
}
