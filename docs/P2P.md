# Harpy P2P networking

Harpy nodes can gossip blocks over a TCP JSON protocol, buffer out-of-order arrivals in an orphan pool, and resolve forks by cumulative proof-of-work with UTXO-consistent reorgs. P2P is **enabled by default** when the HTTP server starts; disable it with `HARPY_P2P_DISABLE=1` for single-node-only runs.

**Scope:** educational multi-node demos on a trusted LAN. Not production-grade Sybil or BGP resistance — see [ROUTING_PARTITION.md](./ROUTING_PARTITION.md) and [SYBIL_RESISTANCE.md](./SYBIL_RESISTANCE.md).

## Architecture

```
HTTP (Kemal)                    P2P (TCP)
POST /mine ──broadcast──►  inv ──► getblock ──► block
POST /tx   (mempool)       ▲                      │
                           └──── accept_block! ◄──┘
                                    │
                         orphan pool / reorg_to!
```

| Component | File | Role |
|-----------|------|------|
| `P2p::Network` | `src/harpy/p2p/gossip.cr` | Listen, dial peers, route messages |
| `P2p::Protocol` | `src/harpy/p2p/protocol.cr` | JSON message types and wire framing |
| `OrphanPool` | `src/harpy/p2p/orphan_pool.cr` | Buffer blocks whose parent is unknown (max 100) |
| `PeerManager` | `src/harpy/p2p/peer_manager.cr` | Connection limits, bans, eclipse guard |
| `Reputation` | `src/harpy/p2p/reputation.cr` | Inv spam scoring; deprioritize low-score peers |
| `Chain#accept_block!` | `src/harpy/chain.cr` | Connect, orphan, or reorg on heavier valid fork |

Locally mined blocks (`POST /mine`) are saved to disk and broadcast via `inv` with the block hash. Peers that do not have the block respond with `getblock`; the sender replies with the full block JSON.

## Wire protocol

- **Transport:** plain TCP (no TLS in tutorial builds).
- **Framing:** 4-byte big-endian payload length, then UTF-8 JSON (max **512 KiB** per message).
- **Version:** `PROTOCOL_VERSION = 1` in handshake messages.

| Message | Direction | Purpose |
|---------|-----------|---------|
| `handshake` | Both | Exchange `genesis_hash`, `height`, `tip_hash` |
| `handshake_ack` | Both | Acknowledge compatible chain |
| `inv` | Either | Announce block hash(es) |
| `getblock` | Either | Request block by hash |
| `block` | Response | Full `Block` JSON |
| `ping` / `pong` | Either | Liveness |
| `reject` | Response | Block not found or policy rejection |

Handshake **fails** (connection closed) when `genesis_hash` does not match the local chain — nodes on different networks cannot sync.

## Fork choice and reorgs

`Chain#accept_block!` returns one of:

| Result | Meaning |
|--------|---------|
| `Connected` | Block extends the current tip |
| `Reorganized` | A heavier valid fork replaced the active chain; UTXO set replayed via undo log |
| `Orphaned` | Parent unknown or fork not yet heavier — stored in orphan pool |
| `AlreadyHave` | Duplicate block hash |
| `Rejected` | Invalid structure, PoW, or linkage |

Reorg requires **strictly greater** cumulative work (`16^difficulty` per block). Orphan children are processed automatically when a parent connects.

## Peer limits and security

| Control | Value | Notes |
|---------|-------|-------|
| Max outbound peers | 8 | Dial via `HARPY_P2P_PEERS` |
| Max inbound peers | 32 | Accept on `0.0.0.0:HARPY_P2P_PORT` |
| Ban threshold | 10 misbehavior points | 1-hour ban |
| Max peers per /16 subnet | 2 | `EclipseGuard` bucketing |
| Anchor peers | 2 slots | `HARPY_ANCHOR_PEERS` bypass subnet cap |
| Inv rate limit | 50 per 10 s | Reputation penalty on excess |

`/health` exposes P2P status when enabled:

```json
{
  "valid": true,
  "last_saved_at": "2026-07-03T12:00:00Z",
  "p2p": {
    "enabled": true,
    "peers": 3,
    "orphans": 0,
    "eclipse_risk": false,
    "peer_subnets": 2
  }
}
```

`eclipse_risk: true` when fewer than two distinct /16 subnets are represented or one subnet holds more than 75% of peers. Add outbound peers on diverse subnets — see [ROUTING_PARTITION.md](./ROUTING_PARTITION.md).

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `HARPY_P2P_DISABLE` | unset | Set to `1` to skip P2P listener and outbound dials |
| `HARPY_P2P_PORT` | `9333` | TCP port for P2P (listens on all interfaces) |
| `HARPY_P2P_PEERS` | unset | Comma-separated bootstrap peers (`host` or `host:port`) |
| `HARPY_ANCHOR_PEERS` | unset | Up to two trusted peers exempt from subnet eviction |
| `HARPY_HTTP_PORT` / `PORT` | `3000` | HTTP API port (use distinct values per local node) |
| `HARPY_DATA_DIR` | `data/chain.json` | **Must differ per node** on the same host |
| `HARPY_GENESIS_PUBKEY` | tutorial default | Must match across peers for handshake |

P2P binds to `0.0.0.0` regardless of `HARPY_BIND_HOST` (HTTP bind). Firewall P2P ports appropriately on exposed hosts.

## Multi-node local demo

Run two nodes on one machine with separate chain files and ports:

```bash
# Terminal 1 — seed node
rm -f /tmp/harpy-a.json
HARPY_DATA_DIR=/tmp/harpy-a.json \
HARPY_HTTP_PORT=3000 \
HARPY_P2P_PORT=9333 \
HARPY_DIFFICULTY=1 \
crystal run src/harpy.cr

# Terminal 2 — joins node A
rm -f /tmp/harpy-b.json
HARPY_DATA_DIR=/tmp/harpy-b.json \
HARPY_HTTP_PORT=3001 \
HARPY_P2P_PORT=9334 \
HARPY_P2P_PEERS=127.0.0.1:9333 \
HARPY_DIFFICULTY=1 \
crystal run src/harpy.cr
```

Copy the genesis chain from node A before starting B, or use the same `HARPY_GENESIS_PUBKEY` and `HARPY_DIFFICULTY` so both bootstraps produce compatible genesis blocks. In practice, **copy `harpy-a.json` to `harpy-b.json`** before starting B, or mine only on one node and let gossip propagate.

Mine on node A:

```bash
curl -X POST http://localhost:3000/mine \
  -H "Content-Type: application/json" \
  -d '{"miner_pubkey":"a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"}'
```

Verify sync on node B:

```bash
curl http://localhost:3001/validate
curl http://localhost:3001/health   # check p2p.peers > 0
```

Integration coverage: `spec/p2p_spec.cr`, `spec/p2p_reorg_integration_spec.cr`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Handshake fails immediately | Different genesis (`HARPY_GENESIS_PUBKEY` or chain file) | Align genesis; copy chain file or reset both |
| `p2p.peers: 0` | Wrong `HARPY_P2P_PEERS`, firewall, or port clash | Check dial address includes port; verify `HARPY_P2P_PORT` unique per node |
| Heights diverge | Partition or competing miners on equal work | Wait for heavier fork; check [CONFIRMATION_DEPTH.md](./CONFIRMATION_DEPTH.md) |
| `eclipse_risk: true` | All peers on same /16 | Add `HARPY_P2P_PEERS` on other subnets or set `HARPY_ANCHOR_PEERS` |
| Orphans not clearing | Parent block never received | Ensure inv/getblock path works; check peer bans in logs |

## Related documents

- [DEMO.md](./DEMO.md) — HTTP API and single-node walkthrough
- [STATE_MODEL.md](./STATE_MODEL.md) — UTXO, mempool, reorg undo log
- [THREAT_MODEL.md](./THREAT_MODEL.md) — API and network threat catalog
- [ROUTING_PARTITION.md](./ROUTING_PARTITION.md) — BGP/partition operator guidance
