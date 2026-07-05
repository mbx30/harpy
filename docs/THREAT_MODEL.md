# Harpy threat model

Harpy is an **educational, single-node** proof-of-work blockchain with an open HTTP mining API. This document enumerates threats that apply **today** (no P2P networking) and maps them to mitigations in the codebase or deferred work in Linear.

**Scope:** one Kemal process, JSON file persistence, PoW with configurable hex-digit difficulty, cumulative-work fork choice on in-memory replacement.

**Out of scope (deferred):** P2P gossip, eclipse/partition resistance, UTXO/account state, production key management, multi-node consensus.

## Layer taxonomy

Following layer-based blockchain security surveys ([Li et al. arXiv:1802.06993](https://arxiv.org/abs/1802.06993), [Saad et al. arXiv:1904.03487](https://arxiv.org/abs/1904.03487), [arXiv:2404.18090](https://arxiv.org/abs/2404.18090)):

| Layer | Harpy today | Primary risks |
|-------|-------------|---------------|
| **Consensus** | PoW, cumulative work fork choice | Selfish mining, stale forks |
| **Network** | None (HTTP only) | N/A until P2P → [MIC-39](https://linear.app/mbx2/issue/MIC-39) |
| **Node / API** | Kemal HTTP server | Mining DoS, unauthorized writes |
| **Storage** | `chain.json` on disk | Tampering, partial writes |
| **Cryptography** | SHA-256 block hashes | Collision resistance (theoretical) |

## Assets and trust boundaries

| Asset | Why it matters |
|-------|----------------|
| Chain state (`data/chain.json`) | Source of truth for block history |
| Mining CPU | PoW is intentionally expensive |
| Write API (`POST /new-block`) | Anyone who can mine can extend the chain |

**Trust assumptions (tutorial):**

- Operator controls the host and filesystem.
- No adversarial P2P peers (single node).
- PoW makes block extension costly; difficulty is not retargeted yet.

## Threat catalog

### 1. Open mining endpoint DoS (API layer)

**Attack:** Flood `POST /new-block` to force CPU-heavy mining on the server.

**Impact:** CPU exhaustion, slow or unavailable API.

**Mitigations (in repo):**

- Per-IP token bucket on `POST /new-block` → HTTP 429 ([MIC-41](https://linear.app/mbx2/issue/MIC-41)).
- Optional `HARPY_API_KEY` for write auth in deployment ([MIC-43](https://linear.app/mbx2/issue/MIC-43)).

**Residual risk:** Distributed flood from many IPs; no global quota. **Deferred:** [MIC-68](https://linear.app/mbx2/issue/MIC-68) (broader hardening), production reverse proxy / WAF.

Tune defaults with `HARPY_RATE_LIMIT` (bucket capacity, default `2`) and `HARPY_RATE_LIMIT_WINDOW` (refill interval in seconds, default `10`). See [DEMO.md](./DEMO.md#6-rate-limiting).

### 1b. Oversized request bodies (API layer)

**Attack:** Send very large JSON bodies to `/new-block` to consume memory or CPU before rejection.

**Impact:** Memory pressure, slow parsing, potential DoS adjunct to mining abuse.

**Mitigations (in repo):**

- Kemal `max_request_body_size` capped at 64 KiB (`Harpy::Config::MAX_REQUEST_BODY_BYTES`) → HTTP 413 ([MIC-38](https://linear.app/mbx2/issue/MIC-38)).
- Block `data` field capped at 32 KiB after parse → HTTP 400.

**Residual risk:** Many small valid requests still trigger mining. Combine with rate limits and write auth.

### 2. Unauthorized chain extension

**Attack:** Anonymous clients append blocks when the node is exposed on a network.

**Impact:** Unwanted chain growth, disk use, operator loss of control over who mines.

**Mitigations:**

- `HARPY_API_KEY` + `Authorization: Bearer` or `X-API-Key` on writes when set.
- Tutorial default: no key (local dev only).

**Residual risk:** Key leakage, no rotation story. **Deferred:** secrets management, TLS termination.

### 3. Selfish mining / fork choice games (consensus)

**Attack:** With P2P, a miner withholds blocks and releases forks strategically. Profitable below classical 51% in some models (~25% at γ=0.5; MDP-optimal ≈23.21%).

**Impact today:** Limited — no P2P means no multi-miner race on one network view. Logic still matters for `Chain#replace_if_more_work_valid!` when loading alternate histories.

**Mitigations:**

- Cumulative work scoring (`16^difficulty` per block) instead of block count alone ([MIC-35](https://linear.app/mbx2/issue/MIC-35)).

**Residual risk:** No network propagation rules, no confirmation-depth policy. **Deferred:** [MIC-69](https://linear.app/mbx2/issue/MIC-69), [MIC-71](https://linear.app/mbx2/issue/MIC-71).

### 4. Timestamp manipulation

**Attack:** Backdate or skew block timestamps to affect ordering or future difficulty retargeting.

**Impact:** Invalid blocks rejected at append; monotonic timestamp rule (child ≥ parent).

**Mitigations:** `Block#valid_against?` timestamp check ([MIC-31](https://linear.app/mbx2/issue/MIC-31)).

**Residual risk:** No median-time-past or drift bounds. **Deferred:** adjustable difficulty ([roadmap](https://linear.app/mbx2/project/harpy-16c5704dd57d/overview)).

### 5. Disk tampering and persistence failures (storage)

**Attack:** Edit `chain.json`, truncate file, or swap in an invalid chain.

**Impact:** Node refuses invalid chain on boot (`StorageError`); valid tampered chain could be accepted if PoW checks pass.

**Mitigations:**

- Full-chain validation on load (`Chain#valid?`).
- Configurable path via `HARPY_DATA_DIR` ([MIC-43](https://linear.app/mbx2/issue/MIC-43)).
- Atomic writes (temp file + `fsync` + rename) and a SHA-256 checksum envelope (`{version, checksum, blocks}`) — a crash mid-write cannot corrupt `chain.json`, and a checksum mismatch on load raises `StorageError` before the chain is trusted.

**Residual risk:** No directory-entry `fsync` after rename (not portable to Windows) — a crash between rename and the directory's own metadata sync could, in principle, leave the rename unobserved after an OS-level crash, though the target file's contents remain internally consistent either way. No signature (checksum protects against corruption/tampering-without-the-signing-key-workflow, not an operator with filesystem write access who can also recompute a valid checksum). **Deferred:** embedded KV ([roadmap](https://linear.app/mbx2/project/harpy-16c5704dd57d/overview)).

### 6. Block / hash integrity

**Attack:** Alter `hash`, `prev_hash`, or `nonce` in JSON without redoing PoW.

**Impact:** Rejected by `hash_matches?`, linkage, and `pow_valid?` checks.

**Mitigations:** Deterministic `computed_hash` (see `spec/fixtures/hash_vectors.json`, [MIC-30](https://linear.app/mbx2/issue/MIC-30)).

### 7. Sybil identity flood (network — not yet applicable)

**Attack:** Many fake node identities to eclipse or partition honest peers.

**Impact:** N/A without P2P.

**Deferred:** [MIC-92](https://linear.app/mbx2/issue/MIC-92), [MIC-68](https://linear.app/mbx2/issue/MIC-68), [MIC-87](https://linear.app/mbx2/issue/MIC-87).

### 8. Eclipse / BGP partition (network — not yet applicable)

**Attack:** Isolate a node’s view of the network to feed a weaker fork.

**Impact:** N/A on single-node HTTP tutorial.

**Deferred:** [MIC-68](https://linear.app/mbx2/issue/MIC-68), [MIC-87](https://linear.app/mbx2/issue/MIC-87).

## Cumulative work choice

Harpy scores each block as **`work = 16^difficulty`** (i.e. `1 << (4 * difficulty)`), matching the expected number of hash trials for `difficulty` leading hex zeroes. Fork replacement requires **strictly greater** cumulative work on a fully valid candidate chain.

This closes the “same height, weaker PoW” gap from naive longest-chain-by-count rules but does **not** alone stop selfish mining once P2P exists.

## Deployment guidance (tutorial → staging)

| Control | Tutorial (local) | Exposed deployment |
|---------|------------------|-------------------|
| `HARPY_API_KEY` | Unset | Set; terminate TLS at proxy |
| Rate limit | `HARPY_RATE_LIMIT=2`, `HARPY_RATE_LIMIT_WINDOW=10` | Tune capacity/refill; add edge rate limits |
| Request size | 64 KiB body / 32 KiB `data` (fixed in code) | Same; reject at reverse proxy if desired |
| `HARPY_DATA_DIR` | `data/chain.json` | Dedicated volume, backups |
| Exposure | `localhost` only | Firewall; do not expose mining to the public internet |

## Related documents and issues

- [DEMO.md](./DEMO.md) — runbook and API exercises
- [AGENTS.md](../AGENTS.md) — architecture and commands
- [MIC-33](https://linear.app/mbx2/issue/MIC-33) — this document
- [MIC-35](https://linear.app/mbx2/issue/MIC-35) — cumulative work
- [MIC-39](https://linear.app/mbx2/issue/MIC-39) — P2P (future attack surface)
- [MIC-38](https://linear.app/mbx2/issue/MIC-38) — HTTP body size limit
- [MIC-41](https://linear.app/mbx2/issue/MIC-41) — rate limiting
- [MIC-43](https://linear.app/mbx2/issue/MIC-43) — environment config
- [MIC-68](https://linear.app/mbx2/issue/MIC-68) — eclipse countermeasures
- [MIC-69](https://linear.app/mbx2/issue/MIC-69) — selfish mining thresholds
- [MIC-71](https://linear.app/mbx2/issue/MIC-71) — confirmation depth (Gervais MDP)
- [MIC-81](https://linear.app/mbx2/issue/MIC-81) — Merkle anchoring API (future use case)

## References

- Li et al., [A Survey on the Security of Blockchain Systems](https://arxiv.org/abs/1802.06993)
- Saad et al., [Exploring the Attack Surface of Blockchain](https://arxiv.org/abs/1904.03487)
- Eyal & Sirer, selfish mining
- Gervais et al., [On the Security and Performance of Proof of Work Blockchains](https://eprint.iacr.org/2016/555)
- Internal: [production readiness research](https://app.notion.com/p/berrymichael/production-ready-29c4b9c70df84cc8a5a503b845c80541), [hardening plan](https://app.notion.com/p/3919cb079ddb8132ae08f16afdd9f0a0)
