# Staging testnet (MIC-74)

A persistent multi-node testnet is the last testing tier before anything is
called "released": real gossip, real reorgs, real storage across process
restarts — network-scale behavior that unit and integration specs cannot
exercise. This runbook stands one up with a single command and defines the
operating discipline around it.

Topology and P2P behavior: [P2P.md](./P2P.md). Deployment guardrails:
[THREAT_MODEL.md](./THREAT_MODEL.md) and [NODE_HARDENING.md](./NODE_HARDENING.md).

## Stand it up

```bash
docker compose -f docker-compose.testnet.yml up -d --build
```

Three nodes (`seed`, `node2`, `node3`) gossip over an internal network; each
persists its chain in a named Docker volume, so state survives restarts and
image rebuilds. HTTP APIs are published on the **host loopback only**:

| Node | API | Bootstrap peers |
|------|-----|-----------------|
| seed | `http://127.0.0.1:3001` | — |
| node2 | `http://127.0.0.1:3002` | seed |
| node3 | `http://127.0.0.1:3003` | seed, node2 |

Smoke test — mine on one node, watch it arrive on another:

```bash
curl -s http://127.0.0.1:3002/health
curl -s -X POST http://127.0.0.1:3001/mine \
  -H 'Content-Type: application/json' \
  -d '{"miner_pubkey":"<64-hex-ed25519-pubkey>"}'
curl -s http://127.0.0.1:3003/validate   # height advances via gossip
```

## Operating discipline

- **Pre-release validation.** Every candidate build runs here before tagging:
  `docker compose -f docker-compose.testnet.yml up -d --build` on the release
  branch, then the smoke test above plus a forced reorg (stop `node3`, mine two
  blocks on `seed`, one on restarted `node3`, confirm it adopts the heavier
  chain and `/validate` agrees across nodes).
- **Persistence policy.** Volumes are kept across releases. A **chain reset**
  (`docker compose -f docker-compose.testnet.yml down -v`) is a breaking event:
  announce it, and bump `HARPY_DIFFICULTY`/genesis settings only at reset
  boundaries.
- **Monitoring.** `GET /health` on each node is the liveness probe (Docker
  healthchecks poll it every 30s); it reports chain validity, peer count, and
  eclipse-risk status. Persist the output somewhere visible (cron + append to a
  log is enough at this scale).
- **Chaos hooks.** The consensus chaos harness
  ([spec/chaos_harness_spec.cr](../spec/chaos_harness_spec.cr)) covers
  fault-injection at the process level; at the network level use
  `docker pause`/`docker network disconnect` on individual nodes (Pumba-style,
  per ChaosETH [arXiv:2111.00221](https://arxiv.org/abs/2111.00221)) and assert
  the survivors converge afterwards.

## Going public

The compose file deliberately binds to `127.0.0.1`. Before publishing the API
or P2P port on a public address, work through the checklist — all switches
already exist:

1. Set `HARPY_API_KEY` (in `.env`) so `/tx`, `/mine`, and `/anchor` require
   auth; verify a 401 without it.
2. Keep rate limits at defaults or tighter (`HARPY_RATE_LIMIT`,
   `HARPY_RATE_LIMIT_WINDOW`); they bound PoW CPU burn per client.
3. Prefer async mining (`POST /mine` with `"async": true`) for anything
   internet-facing — queue depth, not request volume, bounds CPU (MIC-44).
4. Front with a reverse proxy for TLS, and only then set `HARPY_TRUST_PROXY`.
5. Review [ROUTING_PARTITION.md](./ROUTING_PARTITION.md) and the eclipse
   countermeasures in [P2P.md](./P2P.md) before advertising P2P publicly —
   set `HARPY_ANCHOR_PEERS` on every non-seed node.
6. Pick a host and DNS name; any single small VM running this compose file is
   sufficient for the educational testnet. Publishing is a hosting decision,
   not a code change.

Remember the scope: this is a **staging** net for an educational chain. It
validates releases and integration flows; it makes no availability or
consensus-security promises to third parties.
