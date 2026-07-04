# Node hardening runbook (MIC-75)

Operational security for a Harpy node. Most real blockchain losses are not broken
cryptography — they are exposed keys, unauthenticated RPC, and trust routed
through a single gateway. This runbook covers the controls Harpy ships and the
deployment practices around them.

## RPC endpoint controls

| Endpoint | Method | Auth | Rate-limited |
|----------|--------|------|--------------|
| `/`, `/validate`, `/block/:i`, `/header/:i`, `/headers`, `/proof/...`, `/mempool` | GET | none (read-only) | no |
| `/anchor/:record_hash` | GET | none (read-only) | no |
| `/tx` | POST | `HARPY_API_KEY` when set | yes |
| `/mine` | POST | `HARPY_API_KEY` when set | yes |
| `/anchor` | POST | `HARPY_API_KEY` when set | yes |

- **Authenticate writes.** Set `HARPY_API_KEY`; clients send `Authorization: Bearer <key>` or `X-API-Key`. Without it, write endpoints accept anonymous requests (local-dev default only — never expose an unauthenticated write port).
- **Rate-limit writes.** All mutating POSTs share a per-client token bucket (`HARPY_RATE_LIMIT`, `HARPY_RATE_LIMIT_WINDOW`) returning HTTP 429 on exceed. See [rate_limit.cr](../src/harpy/rate_limit.cr).
- **Bound request bodies.** `max_request_body_size` (64 KiB) → HTTP 413 before parsing.

## Never route trust through a single proxy

Client identity for rate limiting comes from the TCP peer address by default.
`X-Forwarded-For` is honored **only** when `HARPY_TRUST_PROXY` is set, because a
directly-reachable node sees a fully client-controlled value there — trusting it
unconditionally lets an attacker forge a fresh identity per request and defeat
the limit. Enable `HARPY_TRUST_PROXY` **only** when the node sits behind a proxy
you control that overwrites `X-Forwarded-For`. This mirrors the provenance lesson
that a single trusted gateway is a single point of compromise.

## Network exposure

- **Bind to loopback by default** (`HARPY_BIND_HOST=127.0.0.1`). Only bind `0.0.0.0` behind a firewall/reverse proxy, and only with `HARPY_API_KEY` set.
- **Separate ports.** HTTP RPC (`HARPY_HTTP_PORT`) and P2P (`HARPY_P2P_PORT`) are distinct; expose only what a given host needs. A pure miner/RPC node need not expose P2P publicly; a relay need not expose write RPC.
- **P2P peer hygiene** is enforced in-node: peer caps, misbehavior banning, eclipse-risk accounting (see [p2p/peer_manager.cr](../src/harpy/p2p/peer_manager.cr), [p2p/eclipse.cr](../src/harpy/p2p/eclipse.cr)).

## Key custody

- **No validator/miner private key on an internet-exposed host.** The miner
  payout uses only a *public* key (`POST /mine {miner_pubkey}`); signing of
  transactions happens client-side. Keep signing keys off the node.
- For shared control of high-value keys, see [THRESHOLD_MULTISIG.md](./THRESHOLD_MULTISIG.md).
- For rotation and compromise response, see [KEY_ROTATION.md](./KEY_ROTATION.md).

## Pre-exposure checklist

- [ ] `HARPY_API_KEY` set (strong, unique) and delivered to clients out-of-band.
- [ ] `HARPY_BIND_HOST` not `0.0.0.0` unless firewalled + reverse-proxied.
- [ ] `HARPY_TRUST_PROXY` set **only** behind a trusted proxy.
- [ ] Rate limits tuned for expected legitimate load.
- [ ] Signing keys absent from the node host.
- [ ] Chain file (`HARPY_DATA_DIR`) on a backed-up volume; integrity verified via `verify-chain` (see [STORAGE_BACKENDS.md](./STORAGE_BACKENDS.md)).
- [ ] Incident procedure reviewed ([INCIDENT_RESPONSE.md](./INCIDENT_RESPONSE.md)).
