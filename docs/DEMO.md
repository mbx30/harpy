# Harpy demo walkthrough

This guide walks through running Harpy, exercising the HTTP API, changing proof-of-work difficulty, running multiple nodes over P2P, and running the test suite.

Harpy is an **educational** chain with UTXO transactions and optional P2P gossip. Its long-term direction is a **verification and anchoring layer** (hash on-chain, payload off-chain) — see [MIC-81](https://linear.app/mbx2/issue/MIC-81).

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

On first boot the server mines a **genesis block** (coinbase to the default genesis pubkey) and saves it to `data/chain.json`. Default difficulty is **3** leading hex zeros.

## 2. HTTP demo (curl)

| Step | Command | What to observe |
|------|---------|-----------------|
| View chain | `curl http://localhost:3000/` | JSON array; genesis `hash` starts with `000` |
| Health check | `curl http://localhost:3000/health` | `valid`, `last_saved_at`, and `p2p` status |
| Validate | `curl http://localhost:3000/validate` | `height`, cumulative `work`, `tip` hash |
| Mempool | `curl http://localhost:3000/mempool` | `{"transactions":[]}` on a fresh chain |
| Mine a block | `curl -X POST http://localhost:3000/mine -H "Content-Type: application/json" -d '{"miner_pubkey":"a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"}'` | Block JSON with coinbase tx; nonce logged |
| Lookup block | `curl http://localhost:3000/block/1` | Block 1 links to genesis via `prev_hash` |
| Persistence | `cat data/chain.json` | Checksum envelope with blocks array |

`miner_pubkey` must be a 64-character hex Ed25519 public key. The tutorial default genesis pubkey is `a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456` (override genesis with `HARPY_GENESIS_PUBKEY`).

Signed user transactions use `POST /tx` — see [STATE_MODEL.md](./STATE_MODEL.md) for the JSON schema and signing digest.

## 3. Change mining difficulty (`HARPY_DIFFICULTY`)

Difficulty applies **only when creating a new chain** (no `data/chain.json` yet). Existing chains keep their stored difficulty; retargeting adjusts every 10 blocks toward a 60-second target.

```bash
rm -f data/chain.json
HARPY_DIFFICULTY=1 crystal run src/harpy.cr
```

| Difficulty | Leading zeros | Approx. average hashes |
|------------|---------------|-------------------------|
| 1 | `0` | 16 |
| 3 | `000` | 4,096 |
| 4 | `0000` | 65,536 |

Invalid values (negative or non-numeric) fall back to `DEFAULT_DIFFICULTY` (3).

## 4. Request size limits

`POST /tx` and `POST /mine` enforce caps (see `Harpy::Config`):

| Limit | Default | HTTP status |
|-------|---------|-------------|
| JSON request body | 64 KiB | 413 Payload Too Large |
| Block transactions JSON | 32 KiB | 400 / validation reject |

Oversized bodies are rejected before parsing. The transactions cap is also enforced in `Block#valid_against?`, not only at the HTTP layer.

## 5. Write authentication (`HARPY_API_KEY`)

By default, `POST /tx` and `POST /mine` accept anonymous writes (local development only). Set `HARPY_API_KEY` to require credentials.

```bash
HARPY_API_KEY=dev-secret crystal run src/harpy.cr
```

```bash
curl -X POST http://localhost:3000/mine \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer dev-secret" \
  -d '{"miner_pubkey":"a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"}'
```

Read endpoints remain unauthenticated.

## 6. Rate limiting

`POST /tx` and `POST /mine` use a per-client token bucket (default: **2** requests per **10** seconds).

| Variable | Default | Meaning |
|----------|---------|---------|
| `HARPY_RATE_LIMIT` | `2` | Bucket capacity |
| `HARPY_RATE_LIMIT_WINDOW` | `10` | Seconds between refills |
| `HARPY_TRUST_PROXY` | unset | Trust `X-Forwarded-For` (trusted proxy only) |

Exceeding the limit returns HTTP **429**. `GET` routes are not rate limited.

## 7. Custom chain storage (`HARPY_DATA_DIR`)

```bash
HARPY_DATA_DIR=custom-data crystal run src/harpy.cr          # → custom-data/chain.json
HARPY_DATA_DIR=/var/lib/harpy/chain.json crystal run src/harpy.cr
```

On boot, existing files are loaded and validated. Tampered chains raise `StorageError` and refuse to start.

### Durability and integrity

- **Atomic writes:** temp file + rename
- **Checksum envelope:** `{"checksum":"…","blocks":[…]}` verified before chain construction
- **Backend interface:** see [STORAGE_BACKENDS.md](./STORAGE_BACKENDS.md)

## 8. CLI commands

```bash
crystal run src/harpy.cr -- verify-chain --path data/chain.json
crystal run src/harpy.cr -- export-chain --path data/chain.json --out backup.json
crystal run src/harpy.cr -- help
```

## 9. Network binding

| Variable | Default | Scope |
|----------|---------|-------|
| `HARPY_BIND_HOST` | `127.0.0.1` | HTTP API only |
| `HARPY_HTTP_PORT` / `PORT` | `3000` | HTTP API |

```bash
HARPY_BIND_HOST=0.0.0.0 HARPY_API_KEY=dev-secret crystal run src/harpy.cr
```

P2P listens on `0.0.0.0:HARPY_P2P_PORT` separately — see [P2P.md](./P2P.md).

## 10. Multi-node P2P demo

P2P is on by default. Run two nodes with distinct data dirs and ports:

```bash
# Node A
rm -f /tmp/harpy-a.json
HARPY_DATA_DIR=/tmp/harpy-a.json HARPY_HTTP_PORT=3000 HARPY_P2P_PORT=9333 \
  HARPY_DIFFICULTY=1 crystal run src/harpy.cr

# Node B (copy A's chain file so genesis matches, then join)
cp /tmp/harpy-a.json /tmp/harpy-b.json
HARPY_DATA_DIR=/tmp/harpy-b.json HARPY_HTTP_PORT=3001 HARPY_P2P_PORT=9334 \
  HARPY_P2P_PEERS=127.0.0.1:9333 HARPY_DIFFICULTY=1 crystal run src/harpy.cr
```

Mine on A; confirm B's height catches up via `curl http://localhost:3001/validate` and `curl http://localhost:3001/health`.

Disable P2P for single-node-only: `HARPY_P2P_DISABLE=1`.

Full protocol, limits, and troubleshooting: **[P2P.md](./P2P.md)**.

## 11. Structured logging

```
INFO  - harpy.server: block_accepted index=1 hash=000abc... height=2
INFO  - harpy.p2p: p2p_listening port=9333
WARN  - harpy.server: block_rejected index=2 prev_hash=deadbeef
```

## 12. Automated tests

```bash
crystal spec
crystal tool format --check
shards build
```

Specs use `difficulty: 0` in helpers so mining finishes instantly. Hash vectors: `spec/fixtures/hash_vectors.json`.

### Validation rules exercised in tests

- Hash matches `computed_hash` (length-prefixed `harpy-block-v2` over index, timestamp, `merkle_root`, `prev_hash`, nonce)
- PoW prefix matches `difficulty`
- Linkage: `index` increments; `prev_hash` matches parent
- Timestamps: child ≥ parent (monotonic)
- Transactions: Ed25519 signatures, UTXO balance, `MIN_TX_FEE` floor

## 13. Research context

| Layer | Harpy demonstrates today | Deferred |
|-------|--------------------------|----------|
| **Tutorial** | PoW, UTXO, HTTP API, P2P gossip, reorgs | Production deployment |
| **Hardening** | Cumulative-work fork choice, rate limits, write auth, eclipse detection | BGP monitoring, WAF, TLS |
| **Anchoring** | Merkle roots in block headers | MIC-81 anchoring API |

See **[THREAT_MODEL.md](./THREAT_MODEL.md)** for the threat catalog.

## 14. Anchoring endgame

Applications commit digests (e.g. Merkle roots) on-chain while keeping payloads off-chain. The chain proves a hash existed at a point in time — it is not a database for arbitrary large blobs. Tracked as [MIC-81](https://linear.app/mbx2/issue/MIC-81).
