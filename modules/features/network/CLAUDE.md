# Network features

Repo-wide rules are in the root `CLAUDE.md`.

## Adding a service to CrowdSec

Acquisitions read **journald, not log files**. The file-glob route looks
reasonable and silently collects nothing: NixOS writes per-service logs mode
0600, and crowdsec runs as a dynamic user that cannot read them — which is how
the caddy acquisition sat empty for a while.

The journald source needs care in one place. `crowdsecurity/caddy-logs` runs
`UnmarshalJSON` on `evt.Parsed.message`, and journald hands over the
syslog-prefixed line (`May 14 ... caddy[123]: {json}`), which fails to parse — so
that acquisition passes `--output=cat` to get the bare `MESSAGE` field. The
grok-based ones (sshd, jellyfin, immich) *want* the prefix, so they must not.

Collections that belong to one service live in that service's module, next to
its acquisition; only genuinely generic ones sit in `crowdsec.nix`.
