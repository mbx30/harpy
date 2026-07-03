# Harpy threat model

Harpy is an **educational** proof-of-work blockchain with an HTTP API for signed transactions and mining, plus an optional **P2P block gossip layer** (TCP JSON, cumulative-work reorgs). This document enumerates threats that apply to the current codebase and maps them to mitigations or deferred work in Linear.

**Scope:** Kemal HTTP server, optional P2P (`HARPY_P2P_DISABLE=1` for single-node), JSON file persistence, UTXO state, PoW with difficulty retargeting, cumulative-work fork choice.

**Out of scope (deferred):** production key management, BGP/RPKI monitoring, TLS termination. Routing partition surface: [ROUTING_PARTITION.md](./ROUTING_PARTITION.md) ([MIC-87](https://linear.app/mbx2/issue/MIC-87)). P2P operations: [P2P.md](./P2P.md).

## Layer taxonomy

Following layer-based blockchain security surveys ([Li et al. arXiv:1802.06993](https://arxiv.org/abs/1802.06993), [Saad et al. arXiv:1904.03487](https://arxiv.org/abs/1904.03487), [arXiv:2404.18090](https://arxiv.org/abs/2404.18090)):

| Layer | Harpy today | Primary risks |
|-------|-------------|---------------|
| **Consensus** | PoW, cumulative work fork choice, retargeting | Selfish mining, stale forks |
| **Network** | P2P gossip (optional), peer limits, eclipse guard | Eclipse, inv spam, stale forks — [P2P.md](./P2P.md), [MIC-54](https://linear.app/mbx2/issue/MIC-54) |
| **Node / API** | Kemal HTTP server | Mining DoS, mempool spam, unauthorized writes |
| **Storage** | `chain.json` on disk | Tampering, partial writes |
| **Cryptography** | SHA-256, Ed25519 tx signatures | Forgery, collision (theoretical) |
| **State** | UTXO set + mempool | Double-spend, insufficient balance |

## Assets and trust boundaries

| Asset | Why it matters |
|-------|----------------|
| Chain state (`data/chain.json`) | Source of truth for block history |
| UTXO set (derived on boot) | Spend authority and balances |
| Mempool | Pending spends before inclusion |
| Mining CPU | PoW is intentionally expensive |
| Write API (`POST /tx`, `POST /mine`) | Transaction admission and block extension |

**Trust assumptions (tutorial):**

- Operator controls the host and filesystem.
- P2P peers are untrusted; handshake requires matching `genesis_hash`; blocks are fully validated before connect/reorg.
- PoW makes block extension costly; difficulty retargets every 10 blocks.

## Threat catalog

### 1. Open mining endpoint DoS (API layer)

**Attack:** Flood `POST /mine` to force CPU-heavy mining on the server.

**Impact:** CPU exhaustion, slow or unavailable API.

**Mitigations (in repo):**

- Per-IP token bucket on `POST /mine` and `POST /tx` → HTTP 429 ([MIC-41](https://linear.app/mbx2/issue/MIC-41)). Client identity is the TCP remote address; `X-Forwarded-For` is trusted **only** when `HARPY_TRUST_PROXY` is set.
- Bucket table evicts fully-refilled (idle) entries, bounding memory.
- Optional `HARPY_API_KEY` for write auth ([MIC-43](https://linear.app/mbx2/issue/MIC-43)).

**Residual risk:** Distributed flood from many IPs. **Deferred:** [MIC-68](https://linear.app/mbx2/issue/MIC-68), production reverse proxy / WAF.

Tune with `HARPY_RATE_LIMIT` (default `2`) and `HARPY_RATE_LIMIT_WINDOW` (default `10`). See [DEMO.md](./DEMO.md#6-rate-limiting).

### 1b. Mempool spam (API / state layer)

**Attack:** Flood `POST /tx` with valid-structure but low-value transactions to fill mempool and burden validation.

**Impact:** Memory growth, slower block assembly, operator annoyance.

**Mitigations:**

- `MIN_TX_FEE` floor (`1_000` base units) enforced in `State.validate_tx` and mempool admission ([MIC-61](https://linear.app/mbx2/issue/MIC-61)).
- Rate limits on `POST /tx` (same token bucket as mining).
- Request body cap 64 KiB ([MIC-38](https://linear.app/mbx2/issue/MIC-38)).

**Residual risk:** Many distinct IPs paying minimum fee. **Deferred:** dynamic fee market, global mempool caps.

### 1c. Oversized request bodies (API layer)

**Attack:** Send very large JSON bodies to consume memory before rejection.

**Mitigations:**

- Kemal `max_request_body_size` capped at 64 KiB → HTTP 413 ([MIC-38](https://linear.app/mbx2/issue/MIC-38)).
- Block transactions JSON capped at 32 KiB.

### 2. Unauthorized chain extension and spends

**Attack:** Anonymous clients submit transactions or mine blocks when the node is exposed.

**Mitigations:**

- Ed25519 signatures on all user transactions; mempool and `apply_block` verify signatures.
- `HARPY_API_KEY` on writes when set (constant-time compare).
- Tutorial default: no key (local dev only).

**Residual risk:** Key leakage. **Deferred:** secrets management, TLS termination.

### 2b. Double-spend (state layer)

**Attack:** Spend the same UTXO twice via conflicting mempool txs or competing blocks.

**Mitigations:**

- UTXO set keyed by `OutPoint`; `validate_tx` + mempool conflict check ([STATE_MODEL.md](./STATE_MODEL.md)).
- `apply_block` removes spent UTXOs atomically; per-block undo log for future reorgs.

**Residual risk:** Competing blocks from P2P require confirmation depth — see [CONFIRMATION_DEPTH.md](./CONFIRMATION_DEPTH.md). Mempool conflicts return HTTP 409 on single-node writes.

### 3. Selfish mining / fork choice games (consensus)

**Attack:** With P2P, withhold blocks and release strategic forks (profitable below ~25% hash at γ≈0.5).

**Mitigations:**

- Cumulative work scoring ([MIC-35](https://linear.app/mbx2/issue/MIC-35)).
- **Documented:** [SELFISH_MINING.md](./SELFISH_MINING.md), [CONFIRMATION_DEPTH.md](./CONFIRMATION_DEPTH.md), [FINALITY.md](./FINALITY.md).

### 4. Timestamp manipulation

**Attack:** Skew timestamps to affect difficulty retargeting.

**Mitigations:** Monotonic timestamp rule (`Block#valid_against?`); retargeting uses observed window ([MIC-58](https://linear.app/mbx2/issue/MIC-58)).

**Residual risk:** No median-time-past or drift bounds.

### 5. Disk tampering and persistence failures (storage)

**Attack:** Edit `chain.json`, truncate, or swap chains.

**Mitigations:** Atomic writes, checksum envelope, `Chain#valid?` on load, `verify-chain` CLI.

**Residual risk:** Determined tamperer with checksum recompute — caught by PoW/UTXO validation.

### 6. Block / hash integrity

**Attack:** Alter header fields without redoing PoW.

**Mitigations:** Length-prefixed `harpy-block-v2` preimage with `merkle_root`; cumulative work saturates safely.

### 7. Sybil identity flood (network)

**Attack:** Many fake node identities to eclipse or partition honest peers.

**Mitigations (in repo):**

- PoW makes block forgery expensive ([SYBIL_RESISTANCE.md](./SYBIL_RESISTANCE.md)).
- Peer slot limits, /16 subnet bucketing, anchor peers, misbehavior bans ([P2P.md](./P2P.md)).
- Eclipse risk surfaced in `GET /health` (`p2p.eclipse_risk`).

**Residual risk:** Tutorial-scale Sybil resistance is not mainnet-grade. **Deferred:** [MIC-68](https://linear.app/mbx2/issue/MIC-68), production peer diversity requirements.

### 8. Eclipse / BGP partition (network)

**Attack:** Isolate a node's peer set or cut routing paths to feed a weaker fork.

**Mitigations (in repo):**

- `EclipseGuard` subnet caps and anchor peers; `Eclipse.assess` monitoring.
- Cumulative-work reorg on reconnect when heavier fork arrives.
- Documented operator guidance: [ROUTING_PARTITION.md](./ROUTING_PARTITION.md).

**Residual risk:** No BGP monitoring or multi-homed routing. **Deferred:** ISP-level defenses, [MIC-87](https://linear.app/mbx2/issue/MIC-87).

## Production process

| Topic | Document |
|-------|----------|
| Incident response & releases | [INCIDENT_RESPONSE.md](./INCIDENT_RESPONSE.md) ([MIC-34](https://linear.app/mbx2/issue/MIC-34)) |
| AI-assisted dev gates | [AGENTS.md](../AGENTS.md) ([MIC-32](https://linear.app/mbx2/issue/MIC-32)) |
| Hypothetical PoS long-range | [POS_CHECKPOINTING.md](./POS_CHECKPOINTING.md) ([MIC-88](https://linear.app/mbx2/issue/MIC-88)) — not applicable while PoW |

## Cumulative work choice

Harpy scores each block as **`work = 16^difficulty`**. Fork replacement requires **strictly greater** cumulative work on a fully valid candidate chain.

## Deployment guidance (tutorial → staging)

| Control | Tutorial (local) | Exposed deployment |
|---------|------------------|-------------------|
| `HARPY_API_KEY` | Unset | Set; terminate TLS at proxy |
| Rate limit | `2` / `10 s` window | Tune; add edge rate limits |
| `MIN_TX_FEE` | `1_000` base units | Consider raising for public mempools |
| `HARPY_DATA_DIR` | `data/chain.json` | Dedicated volume, backups |
| Exposure | `localhost` only | Firewall; do not expose mining publicly |
| Confirmations | Depth 1 OK (isolated node) | See [FINALITY.md](./FINALITY.md) — *k*≈6 when P2P is enabled |
| P2P | `HARPY_P2P_DISABLE=1` locally | Diverse `HARPY_P2P_PEERS`; watch `/health` eclipse fields |

## P2P phase note

Phase 5 P2P (gossip, orphans, reorgs, eclipse countermeasures) is **implemented** — see [P2P.md](./P2P.md). Remaining network hardening ([MIC-68](https://linear.app/mbx2/issue/MIC-68), [MIC-87](https://linear.app/mbx2/issue/MIC-87)) is operational and out-of-band relative to the tutorial codebase.

## Related documents and issues

- [STATE_MODEL.md](./STATE_MODEL.md) — UTXO, coinbase, fees, API
- [FINALITY.md](./FINALITY.md) — probabilistic vs strong finality ([MIC-55](https://linear.app/mbx2/issue/MIC-55))
- [SYBIL_RESISTANCE.md](./SYBIL_RESISTANCE.md) — PoW Sybil assumptions ([MIC-92](https://linear.app/mbx2/issue/MIC-92))
- [INCIDENT_RESPONSE.md](./INCIDENT_RESPONSE.md) — release and rollback ([MIC-34](https://linear.app/mbx2/issue/MIC-34))
- [POS_CHECKPOINTING.md](./POS_CHECKPOINTING.md) — PoS decision gate ([MIC-88](https://linear.app/mbx2/issue/MIC-88))
- [DEMO.md](./DEMO.md) — HTTP runbook
- [P2P.md](./P2P.md) — gossip, env vars, multi-node runbook
- [AGENTS.md](../AGENTS.md) — architecture and commands

## References

- Li et al., [A Survey on the Security of Blockchain Systems](https://arxiv.org/abs/1802.06993)
- Saad et al., [Exploring the Attack Surface of Blockchain](https://arxiv.org/abs/1904.03487)
- Gervais et al., [On the Security and Performance of Proof of Work Blockchains](https://eprint.iacr.org/2016/555)
- Platt & McBurney — permissionless Sybil trilemma (see [SYBIL_RESISTANCE.md](./SYBIL_RESISTANCE.md))
