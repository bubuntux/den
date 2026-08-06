# Virtualisation

Repo-wide rules are in the root `CLAUDE.md`.

## Deep links out of the work container

A URL scheme an app in the work container hands off — `slack://`, `zoommtg://`,
`com.cloudflare.warp://` — is answered on the **host**, by a `mkUriOpener`
script that forwards it back into the container. Registering the scheme *inside*
the container looks like the obvious fix and does nothing, which is what cost the
WARP enrollment an afternoon of copy-pasting tokens.

The reason is the session bus. The container's `DBUS_SESSION_BUS_ADDRESS` points
at `/mnt/host-session/bus`, so container-Chrome's OpenURI reaches the **host**
portal, which resolves the scheme against the *host's* mimeapps and — finding
nothing — opens an app-chooser with no candidates in it. Chrome never asks the
container's `xdg-open`. With no host handler registered, `xdg-open` falls
through to launching **firefox** with the deep link.

`Terminal=true` on the shipped `.desktop` entry is not a problem, and looks like
one: xdg-open's `search_desktop_file` execs the `Exec` binary with the remaining
args and never reads `Terminal`.

**Test a handler without spending a real token.** `search_desktop_file` resolves
`Exec`'s first word through `command -v`, so a stub earlier on `PATH` intercepts
the launch and prints the argv it would have received:

```console
$ PATH=/tmp/stub:$PATH xdg-open "com.cloudflare.warp://token?jwt=abc.def&team=x"
STUB argv: [--accept-tos] [registration] [token] [com.cloudflare.warp://token?jwt=abc.def&team=x]
```

That matters because the callback token is only valid for **~30 seconds**
([Cloudflare's own docs](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/warp/deployment/manual-deployment/)
say to refresh the page and grab a new one on a 401), so there is no leisurely
retry loop — and it is why the deep link is worth fixing rather than living with
the paste. The command the handler runs is upstream's:
`warp-cli --accept-tos registration token <url>`. `--accept-tos` is load-bearing
rather than cosmetic — a portal-launched handler has no terminal to answer a ToS
prompt on.

The container keeps its own registration as the fallback for a container-local
`xdg-open`. It costs a line and covers the case where the host portal is out of
the picture.
