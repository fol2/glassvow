---
title: "Tailnet HTTPS needs both a Serve handler and macOS split DNS"
date: 2026-07-31
category: integration-issues
module: developer-tools/tailnet-demo
problem_type: integration_issue
component: tooling
severity: high
symptoms:
  - "A tailnet peer reports `Could not resolve host` for the HTTPS demo while the loopback web service returns HTTP 200"
  - "Direct tailnet-IP HTTP succeeds, but HTTPS port 443 refuses connections"
  - "Tailscale's internal DNS query resolves the host while normal macOS applications do not"
  - "The macOS DNS configuration has no reachable nameserver for `ts.net`"
root_cause: incomplete_setup
resolution_type: environment_setup
related_components:
  - "development_workflow"
  - "documentation"
tags: [tailscale, tailscale-serve, tailnet-https, magicdns, macos-split-dns, resolver, web-demo, remote-verification]
---

# Tailnet HTTPS needs both a Serve handler and macOS split DNS

## Problem

The Glassvow web demo worked on its host but could not be opened at its
tailnet HTTPS URL from a Mac mini. Two independent integration failures
overlapped: the web host had no Tailscale HTTPS Serve handler, and the peer's
macOS system resolver was not routing `ts.net` queries to Tailscale DNS.

The Glassvow tool itself was healthy. Its documented browser endpoint defaults
to loopback port 8766 (`docs/dev-tools.md:14`), matching the host and port
defaults in `tools/dev.py:641-642` (in `main`). A loopback request
returned HTTP 200 before any Tailscale change.

## Symptoms

- `curl https://<tailnet-hostname>/` on the peer exited 6 with
  `Could not resolve host`.
- Direct HTTP to the web host's Tailscale IP returned 200, proving backend and
  peer connectivity without proving DNS or HTTPS.
- TCP 443 refused connections. `tailscale serve status` listed only the
  existing TCP 2200 forward to `127.0.0.1:22`; it had no HTTPS handler.
- After Tailscale DNS acceptance was enabled,
  `tailscale dns query <tailnet-hostname> A` returned the Tailscale IP while
  `dscacheutil -q host -a name <tailnet-hostname>` returned nothing.
- `tailscale dns status --all` reported MagicDNS enabled, but `scutil --dns`
  exposed no reachable `ts.net` nameserver. The generated
  `/etc/resolver/search.tailscale` contained only a search-domain line.

The disagreement between `tailscale dns query` and `dscacheutil` was the useful
boundary: the Tailscale daemon knew the answer, but ordinary macOS applications
could not reach it through the system resolver.

## What Didn't Work

- A loopback HTTP 200 established backend health only. It said nothing about
  peer DNS, tailnet ingress or port 443.
- Direct HTTP to the Tailscale IP bypassed both the hostname resolver and
  HTTPS. It narrowed the fault without satisfying the requested path.
- Earlier sessions made insecure remote HTTP load by selecting Godot's Dummy
  audio driver. That avoided the failed audio worklet, but left the game silent
  instead of providing a secure audio-capable transport. (session history)
- `tailscale set --accept-dns=true` changed `CorpDNS` from false to true, but
  normal macOS resolution still failed, including after a client down/up cycle.
  A preference value is not proof that macOS installed a usable resolver.
- The first `tailscale up --accept-dns=true` recovery was rejected because the
  client already had a non-default hostname. The safe recovery was the complete
  command printed by the CLI, including the existing hostname; shortening it
  would have discarded established preferences.
- The root Homebrew `tailscaled` log claimed its OS configuration included
  `100.100.100.100`; `scutil --dns` contradicted that claim at the
  application-visible layer. Daemon intent was not system resolver state.
- A self-connect check from the serving Mac would not prove peer ingress.
- `tailscale serve reset` was deliberately not used because it would also have
  removed the unrelated TCP 2200 SSH forward.

## Solution

Treat backend, Serve, system DNS and TLS as separate gates. Do the read-only
checks before changing either machine.

### 1. Prove the backend and inventory Serve

On the web host:

```bash
curl -fsS -o /dev/null -w 'HTTP %{http_code}\n' \
  http://127.0.0.1:<web-port>/
tailscale serve status
```

On a tailnet peer:

```bash
tailscale dns query <tailnet-hostname> A
dscacheutil -q host -a name <tailnet-hostname>
tailscale dns status --all
scutil --dns
```

This distinguishes four failure layers:

| Layer | Evidence | Failure means |
|---|---|---|
| Backend | Loopback returns HTTP 200 | The web process itself is down or bound elsewhere |
| Peer route | Direct tailnet-IP HTTP connects | Tailnet reachability is absent |
| DNS | `dscacheutil` returns the peer address | macOS applications cannot resolve the hostname |
| TLS proxy | Peer HTTPS returns 200 with a valid certificate | Serve has no usable HTTPS handler |

### 2. Add the HTTPS handler without replacing SSH

When the backend is healthy and Serve has no HTTPS handler, add only the
missing route:

```bash
tailscale serve --bg --https=443 http://127.0.0.1:<web-port>
tailscale serve status
```

The resulting inventory must retain both independent handlers:

```text
TCP 2200 -> 127.0.0.1:22
https://<tailnet-hostname>/ -> http://127.0.0.1:<web-port>
```

Do not replace the additive command with `tailscale serve reset`. Funnel is
also out of scope: this development control plane stays tailnet-only unless
public exposure is separately authorised.

### 3. Repair the peer's application-visible DNS path

First enable acceptance of the tailnet DNS configuration:

```bash
tailscale set --accept-dns=true
```

If a later `tailscale up` is necessary, copy the complete command printed by
the CLI and retain every existing non-default flag. Do not guess a shortened
replacement.

Only when `tailscale dns query` succeeds while `dscacheutil` fails and
`scutil --dns` has no usable `ts.net` resolver, create the narrow macOS resolver
file. Run this in a visible Terminal on the peer so the administrator enters
the password locally; never request or collect it through a remote session.

```bash
sudo install -d -m 0755 /etc/resolver
printf 'nameserver 100.100.100.100\n' | \
  sudo tee /etc/resolver/ts.net >/dev/null
sudo chmod 0644 /etc/resolver/ts.net
```

The file contains exactly:

```text
nameserver 100.100.100.100
```

This is a conditional repair for the observed Homebrew `tailscaled`/macOS
resolver divergence, not a step every Tailscale client should need.

### 4. Accept the result from a real peer

```bash
dscacheutil -q host -a name <tailnet-hostname>
scutil --dns
curl --fail --show-error --silent --output /dev/null \
  --write-out 'HTTP %{http_code} SSL %{ssl_verify_result}\n' \
  https://<tailnet-hostname>/
nc -vz <tailnet-hostname> 2200
```

The verified result was:

- `dscacheutil` returned the host's Tailscale address;
- `scutil --dns` showed `domain : ts.net`,
  `nameserver[0] : 100.100.100.100` and a reachable resolver;
- peer HTTPS returned HTTP 200 with SSL verification result 0; and
- TCP 2200 remained reachable.

Open the tokenised URL printed by `tools/dev.py` in the peer browser; do not
copy its token into documentation or logs. HTTPS makes the normal browser audio
path available, but the browser still requires one user gesture before sound
can start. Glassvow records the secure-context boundary at
`docs/dev-tools.md:51-57`. A successful TLS request is not, by itself,
audible-output proof.

## Why This Works

Tailscale Serve and MagicDNS solve different parts of the request.

The Serve command creates a tailnet-only TLS listener on port 443 and proxies
it to the already healthy loopback web process. It does not require changing
Glassvow or publishing the controller through Funnel. Adding one handler rather
than resetting Serve preserves the separate SSH forward.

The resolver repair addresses the peer. `tailscale dns query` exercises
Tailscale's DNS path directly, whereas `curl` and the browser depend on macOS
system resolution. The narrow `/etc/resolver/ts.net` entry routes that namespace
to `100.100.100.100`; the final `scutil --dns` state proved that the routing was
application-visible.

Both fixes are required for the hostname URL: fixing Serve alone leaves the
peer unable to find the host, while fixing DNS alone reaches a port that still
refuses HTTPS.

## Prevention

Use this acceptance order whenever Interactive Web leaves loopback:

1. Prove the backend on loopback.
2. Inventory existing Serve handlers before changing them.
3. Add only the missing HTTPS handler.
4. Compare Tailscale's internal DNS answer with the macOS system resolver.
5. Verify DNS, TLS, browser startup and interaction from a real peer.
6. Re-check unrelated ingress, particularly SSH.
7. Perform a user gesture and listen before claiming audio works.

Glassvow deliberately generates a per-session token for non-loopback binding
(`tools/dev.py:662` (in `main`)) and limits this mode to trusted LAN or Tailscale access
(`docs/dev-tools.md:45-54`). Never publish the process: it can export, start,
reload and control development builds. Re-run the resolver and peer checks after
a Tailscale client change; do not assume a daemon preference or an old route
remains application-visible.

## Related Issues

- [A funplay `-32000` means its configured editor backend is unreachable](funplay-mcp-32000-means-editor-backend-unreachable.md)
  is the sibling diagnostic shape: a browser-facing tool can be healthy while
  a required network hop is absent.
- [Capture through a long-lived host, not a process per screenshot](../tooling-decisions/long-lived-capture-host-not-process-per-shot.md)
  records the same rule that configuration read-back is not behavioural proof.
- [Developer tools](../../dev-tools.md) defines Interactive Web, tokenised
  non-loopback access and the secure-context audio boundary.
- [Session ownership](../../session-ownership.md) defines the organiser-owned
  browser front door and trusted Tailscale scope.
- Tailscale's primary references are [Serve](https://tailscale.com/docs/reference/tailscale-cli/serve),
  [MagicDNS](https://tailscale.com/docs/features/magicdns), and
  [DNS in Tailscale](https://tailscale.com/docs/reference/dns-in-tailscale).
