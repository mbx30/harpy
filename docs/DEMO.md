# Harpy demo walkthrough

This guide walks through running Harpy, exercising the HTTP API, changing proof-of-work difficulty, and running the test suite.

Harpy is an **educational** single-node chain. Its long-term direction is a **verification and anchoring layer** (hash on-chain, payload off-chain) — not a general-purpose data store. See [MIC-81](https://linear.app/mbx2/issue/MIC-81) for the future Merkle anchoring API.

## Prerequisites

```bash
shards install
```

On Windows, see [README.md](../README.md) for Crystal and Developer Mode setup.

## 1. Start with a fresh chain

```bash
rm -f data/chain.json
crystal run src/harpy.cr
```

On first boot the server mines a **genesis block** and saves it to `data/chain.json`. Default difficulty is **3** leading hex zeros (`Harpy::Block::DEFAULT_DIFFICULTY`).

## 2. HTTP demo (curl)

| Step | Command | What to observe |
|------|---------|-----------------|
| View chain | `curl http://localhost:3000/` | JSON array; genesis `hash` starts with `000` |
| Health check | `curl http://localhost:3000/health` | `{"valid":true,"last_saved_at":"..."}` — for load-balancer/deployment monitoring |
| Validate | `curl http://localhost:3000/validate` | `{"valid":true,"height":1,"work":4096,"tip":"..."}` — `work` is cumulative PoW score |
| Mine a block | `curl -X POST http://localhost:3000/new-block -H "Content-Type: application/json" -d '{"data":"hello harpy"}'` | Mined block JSON; nonce logged in server output |
| Lookup block | `curl http://localhost:3000/block/1` | Block 1 links to genesis via `prev_hash` |
| Persistence | `cat data/chain.json` | Same blocks on disk |

## 3. Change mining difficulty (`HARPY_DIFFICULTY`)

Difficulty applies **only when creating a new chain** (no `data/chain.json` yet). Existing chains keep their stored difficulty.

```bash
rm -f data/chain.json
HARPY_DIFFICULTY=1 crystal run src/harpy.cr   # faster genesis (~1 hex zero)
```

```bash
rm -f data/chain.json
HARPY_DIFFICULTY=4 crystal run src/harpy.cr   # slower genesis (~4 hex zeros)
```

| Difficulty | Leading zeros | Approx. average hashes |
|------------|---------------|-------------------------|
| 1 | `0` | 16 |
| 3 | `000` | 4,096 |
| 4 | `0000` | 65,536 |

New blocks inherit difficulty from the chain tip (`Miner.mine_next` copies the previous block's difficulty).

Invalid values (negative or non-numeric) fall back to `DEFAULT_DIFFICULTY` (3).

## 4. Request size limits

`POST /new-block` enforces two caps (see `Harpy::Config`):

| Limit | Default | HTTP status |
|-------|---------|-------------|
| JSON request body | 64 KiB (`MAX_REQUEST_BODY_BYTES`) | 413 Payload Too Large |
| Block `data` field | 32 KiB (`MAX_BLOCK_DATA_BYTES`) | 400 Bad Request |

Oversized bodies are rejected before JSON parsing/mining. Keep payloads well under 32 KiB for the `data` string itself.

The block `data` cap is also enforced in `Block#valid_against?` (and genesis validation), not just at the HTTP layer — so a block loaded from storage, replayed via fork choice, or arriving from a future peer can't smuggle an oversize payload past validation.

## 5. Write authentication (`HARPY_API_KEY`)

By default, `POST /new-block` accepts anonymous writes (local development only). Set `HARPY_API_KEY` to require credentials on every mining request.

```bash
HARPY_API_KEY=dev-secret crystal run src/harpy.cr
```

| Header | Example |
|--------|---------|
| `Authorization` | `Bearer dev-secret` |
| `X-API-Key` | `dev-secret` |

```bash
# 401 without credentials
curl -X POST http://localhost:3000/new-block \
  -H "Content-Type: application/json" \
  -d '{"data":"hello"}'

# 200 with Bearer token
curl -X POST http://localhost:3000/new-block \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer dev-secret" \
  -d '{"data":"hello harpy"}'
```

Read endpoints (`GET /`, `/validate`, `/block/:index`) remain unauthenticated.

## 6. Rate limiting

`POST /new-block` uses a per-client token bucket (default: **2** requests per **10** seconds). Tune with:

| Variable | Default | Meaning |
|----------|---------|---------|
| `HARPY_RATE_LIMIT` | `2` | Bucket capacity (max burst) |
| `HARPY_RATE_LIMIT_WINDOW` | `10` | Seconds between token refills |
| `HARPY_TRUST_PROXY` | unset | Trust `X-Forwarded-For` for client identity (behind a trusted proxy only) |

Client identity is the TCP remote address. The first address in `X-Forwarded-For` is used **only when `HARPY_TRUST_PROXY` is set** — on a directly-reachable node that header is attacker-controlled, so trusting it would let a client forge a new identity per request and bypass the limit. Exceeding the limit returns HTTP **429** with `{"error":"rate limit exceeded"}`. `GET` routes are not rate limited.

```bash
HARPY_RATE_LIMIT=1 HARPY_RATE_LIMIT_WINDOW=60 crystal run src/harpy.cr
```

## 7. Custom chain storage (`HARPY_DATA_DIR`)

Default persistence is `data/chain.json`. Override the location for tests or deployments:

```bash
# Directory — writes to custom-data/chain.json
HARPY_DATA_DIR=custom-data crystal run src/harpy.cr

# Explicit file path
HARPY_DATA_DIR=/var/lib/harpy/chain.json crystal run src/harpy.cr
```

On boot, an existing file is loaded and fully validated (`Chain#valid?`). A tampered or invalid chain raises `StorageError` and refuses to start.

### Durability and integrity

- **Atomic writes:** the chain is written to a sibling `chain.json.tmp` then renamed over the target, so a crash mid-write can never leave a partially written file — you always have the previous chain or the complete new one.
- **Checksum envelope:** the file is `{"checksum": "<sha256>", "blocks": [...]}`, where the checksum covers the serialized blocks. On load the checksum is re-verified *before* the chain is built, so bit-rot, truncation, or manual edits are rejected with a `StorageError` (distinct from semantic `Chain#valid?` failures). Legacy bare-array files still load (with a warning).
- Storage sits behind a small backend interface — see [STORAGE_BACKENDS.md](./STORAGE_BACKENDS.md) for the design and the embedded-KV spike.

## 8. CLI commands

With no arguments `harpy` starts the HTTP server (the default). Subcommands are scriptable wrappers over the storage layer and exit non-zero on failure — handy for CI/ops:

```bash
# Validate a chain file (exit 0 if valid, 1 on corruption or invalid chain)
crystal run src/harpy.cr -- verify-chain --path data/chain.json

# Export the chain's blocks as JSON to a file (or stdout if --out is omitted)
crystal run src/harpy.cr -- export-chain --path data/chain.json --out backup.json

# Usage
crystal run src/harpy.cr -- help
```

With a built binary (`shards build`): `./bin/harpy verify-chain --path data/chain.json`.

## 9. Network binding (`HARPY_BIND_HOST`)

By default Harpy binds to `127.0.0.1` — the write API is not reachable outside the local machine unless you opt in.

```bash
# Local only (default)
crystal run src/harpy.cr

# Expose on the LAN for a demo (combine with HARPY_API_KEY in anything beyond a trusted network)
HARPY_BIND_HOST=0.0.0.0 HARPY_API_KEY=dev-secret crystal run src/harpy.cr
```

## 10. Structured logging

Block accepted/rejected events and chain-load validation failures are logged via Crystal's stdlib `Log` module (no secrets — request bodies and API keys are never logged):

```
2026-07-02T18:56:49Z   INFO - harpy.server: block_accepted index=1 hash=000abc... height=2
2026-07-02T18:56:50Z   WARN - harpy.server: block_rejected index=2 prev_hash=deadbeef
2026-07-02T18:56:51Z  ERROR - harpy.storage: chain_load_failed path=data/chain.json reason=validation_failed
```

## 11. Automated tests

```bash
crystal spec
crystal tool format --check
shards build
```

Specs use `difficulty: 0` in helpers so mining finishes instantly. Canonical hash vectors live in `spec/fixtures/hash_vectors.json` (see MIC-30).

### Validation rules exercised in tests

- Hash must match `computed_hash` (SHA-256 over a length-prefixed `harpy-block-v2` encoding of index, timestamp, data, prev_hash, nonce — **not** difficulty)
- Proof-of-work: hash prefix matches `difficulty` leading zeros
- Linkage: `index` increments and `prev_hash` matches parent
- Timestamps: child `timestamp` must be **≥ parent** (monotonic)

## 12. Research context

| Layer | What Harpy demonstrates today | Deferred |
|-------|------------------------------|----------|
| **Tutorial** | PoW blocks, HTTP read/write, JSON persistence | P2P, UTXO/accounts |
| **Production readiness** | Deterministic hashing, chain validation, invalid-chain rejection on boot | Atomic persistence, multi-node deployment |
| **Hardening (Path A/B)** | Cumulative-work fork choice, per-IP rate limits, optional write auth, request/body size caps | P2P fork rules, global quotas, WAF |

See **[THREAT_MODEL.md](./THREAT_MODEL.md)** for the full threat catalog (layers, assets, trust boundaries, Linear issue mapping).

Further reading (attached to Linear issues):

- [Production readiness research](https://app.notion.com/p/berrymichael/production-ready-29c4b9c70df84cc8a5a503b845c80541)
- [Security hardening plan](https://app.notion.com/p/3919cb079ddb8132ae08f16afdd9f0a0)

## 13. Anchoring endgame

Harpy's intended integration pattern is **hash on-chain, data off-chain**: applications commit digests (e.g. Merkle roots of audit logs or records) while keeping payloads in IPFS, object storage, or local systems. The chain proves *that* a hash existed at a point in time — it is not a database for arbitrary large blobs.

That path is tracked separately as Merkle anchoring API work (MIC-81); this tutorial branch establishes the block and validation foundation underneath it.
