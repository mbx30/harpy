# AGENTS.md

Guidance for AI agents working in the **harpy** repository.

## What Harpy is

Harpy is a **Crystal proof-of-work blockchain tutorial**. It is named after [Harpocrates](https://en.wikipedia.org/wiki/Harpocrates), the Greek god of silence (derived from an Egyptian deity symbolizing hope, the newborn sun, and a child).

This is an **educational, single-node** chain — not production blockchain software. It teaches blocks, SHA-256 linking, PoW mining, and HTTP read/write. Networking (P2P, fork choice, reorgs) is explicitly out of scope for the current phase.

**Project tracking:** [Linear — Harpy](https://linear.app/mbx2/project/harpy-16c5704dd57d/overview)

**Reference material:** Crystal port of [Code your own blockchain in Go](https://medium.com/@mycoralhealth/code-your-own-blockchain-in-less-than-200-lines-of-go-e296282bcffc); upstream Crystal example: [bradford-hamilton/crystal-blockchain](https://github.com/bradford-hamilton/crystal-blockchain).

## Stack

- **Language:** [Crystal](https://crystal-lang.org/)
- **HTTP:** [Kemal](https://kemalcr.com/)
- **Package manager:** [Shards](https://crystal-lang.org/reference/latest/man/shards/) (`shard.yml`)
- **Tests:** `spec/` with Crystal's built-in `spec` library

## Architecture (current)

```
src/
  harpy.cr              # Entry point → starts Kemal server
  harpy/
    types.cr            # Harpy::VERSION
    block.cr            # Block struct, SHA-256 hashing, validation
    chain.cr            # In-memory chain, append, fork replacement
    miner.cr            # Proof-of-work mining loop
    storage.cr          # JSON load/save, genesis bootstrap
    config.cr           # Env config, size limits, write auth
    rate_limit.cr       # Per-IP token bucket on POST /new-block
    server.cr           # Kemal HTTP routes
spec/                   # Tests + fixtures/hash_vectors.json
```

### HTTP API

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Return full blockchain as JSON |
| `GET` | `/validate` | Chain validity, height, cumulative work, tip hash |
| `GET` | `/block/:index` | Single block by index |
| `POST` | `/new-block` | Body: `{ "data": "..." }` — mines and appends a block |

`POST /new-block` responses (when validation fails):

| Status | Condition |
|--------|-----------|
| 400 | Missing/invalid/empty `data`, or `data` exceeds 32 KiB |
| 401 | `HARPY_API_KEY` set but request lacks valid credentials |
| 413 | JSON body exceeds 64 KiB (Kemal body limit) |
| 422 | Mined block rejected by chain validation |
| 429 | Per-IP rate limit exceeded on `POST /new-block` |

Default PoW difficulty: **3** leading zero hex digits (`Harpy::Block::DEFAULT_DIFFICULTY`). Override at genesis with `HARPY_DIFFICULTY` (see `docs/DEMO.md`).

### Environment variables

| Variable | Default | Scope |
|----------|---------|-------|
| `HARPY_DIFFICULTY` | `3` | Genesis only (ignored when `chain.json` exists) |
| `HARPY_DATA_DIR` | `data/chain.json` | Directory → `…/chain.json`, or a `.json` file path |
| `HARPY_API_KEY` | unset | When set, writes require `Authorization: Bearer` or `X-API-Key` |
| `HARPY_RATE_LIMIT` | `2` | Max mining requests per client per window |
| `HARPY_RATE_LIMIT_WINDOW` | `10` | Refill interval in seconds for the token bucket |
| `HARPY_TRUST_PROXY` | unset | When truthy, trust `X-Forwarded-For` for client identity (set only behind a trusted reverse proxy) |

Rate limiting applies only to `POST /new-block`. Client identity uses the first `X-Forwarded-For` hop **only when `HARPY_TRUST_PROXY` is set** (a directly-reachable node must not trust that client-supplied header); otherwise it uses the TCP remote address. Idle buckets are evicted once fully refilled to bound memory. See `docs/DEMO.md` for curl examples and `docs/THREAT_MODEL.md` for deployment guidance.

### Hash serialization

`Block#computed_hash` SHA-256 digests a canonical, **length-prefixed** encoding (domain tag `harpy-block-v2`) of `index`, `timestamp`, `data`, `prev_hash`, and `nonce` — each variable field prefixed by its byte length so no field value can spoof another's boundary. **`difficulty` is not included.** Pinned vectors: `spec/fixtures/hash_vectors.json`.

### Validation

Blocks must satisfy linkage, PoW prefix, hash integrity, and **monotonic timestamps** (child ≥ parent).

Fork replacement (`Chain#replace_if_more_work_valid!`) compares **cumulative PoW work** — each block contributes `16^difficulty` (`Block#work`) — not block count alone. Threat model: `docs/THREAT_MODEL.md`.

## Roadmap (from project research)

1. **Done (tutorial + hardening):** blocks, SHA-256, PoW, HTTP API, chain validation, cumulative-work fork choice, rate limits, write auth, request size caps
2. **State model (design gate):** UTXO — see [docs/STATE_MODEL.md](docs/STATE_MODEL.md). Phase 5 blocked until approved.
3. P2P networking — gossip, orphan pool, fork choice, reorgs
4. Persistent storage — atomic writes, embedded KV (RocksDB/LMDB equivalent)
5. Adjustable difficulty — retarget from observed block times
6. Optional: minimal VM with gas metering; Merkle anchoring API (MIC-81)

## Conventions

- `snake_case` for files, methods, and variables; `PascalCase` for modules and classes.
- Keep diffs small. Match existing Crystal style.
- Do not commit unless the user explicitly asks.
- After substantive changes, run `shards install` (if deps changed), `crystal spec`, and smoke-test the server.

## Commands

| Task | Command |
|------|---------|
| Install dependencies | `shards install` |
| Run the server | `crystal run src/harpy.cr` |
| Build release binary | `shards build` |
| Run tests | `crystal spec` |
| Format code | `crystal tool format` |
| Check formatting | `crystal tool format --check` |

## Notes for agents

- Workspace root: `C:\.dev\harpy`
- Windows Crystal support is preview — `winget install CrystalLang.Crystal`
- Crystal path: `%LOCALAPPDATA%\Programs\crystal` — restart terminal after install for PATH
- **Shards requires Windows Developer Mode** (`ms-settings:developers`) for symlinks
- `scripts/setup.ps1` checks Crystal PATH + Developer Mode, then runs `shards install`
- Commit `shard.lock` once dependencies are installed.

## Cursor Cloud specific instructions

Cloud VMs run **Linux** (Ubuntu), not Windows — ignore the Windows/`winget`/Developer-Mode notes above in this environment. Crystal + Shards are preinstalled in the VM image (installed via the official apt repo at `https://crystal-lang.org/install.sh`); the startup update script only runs `shards install`.

Standard commands (see the `## Commands` table) work as written on Linux:

- Run the server: `crystal run src/harpy.cr` → listens on `http://localhost:3000` (`GET /`, `POST /new-block`).
- Tests: `crystal spec`. Format: `crystal tool format[ --check]`. Build: `shards build` → `bin/harpy`.
