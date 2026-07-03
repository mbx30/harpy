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
    economics.cr        # BLOCK_REWARD, fees, maturity, retarget constants
    crypto.cr           # Ed25519 sign/verify (crypto-agile sig_algorithm)
    outpoint.cr         # UTXO outpoint (txid, vout)
    tx_output.cr        # TxOutput (amount, pubkey)
    tx_input.cr         # TxInput (prev_out, signature, sig_algorithm)
    transaction.cr      # Signed transaction + canonical digest
    coinbase_tx.cr      # Coinbase mint transaction
    merkle.cr           # Merkle root over txids
    utxo.cr             # UTXO set + undo entries
    state.cr            # validate_tx, apply_block, coinbase rules
    mempool.cr          # Pending transaction pool
    difficulty.cr       # PoW difficulty retargeting
    block.cr            # Block struct, SHA-256 hashing, validation
    chain.cr            # In-memory chain, UTXO replay, fork replacement
    miner.cr            # Proof-of-work mining loop
    storage.cr          # JSON load/save, genesis bootstrap
    config.cr           # Env config, size limits, write auth
    rate_limit.cr       # Per-IP token bucket on POST /mine and /tx
    server.cr           # Kemal HTTP routes
    cli.cr              # verify-chain, export-chain
spec/                   # Tests + fixtures/hash_vectors.json
```

### HTTP API

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Return full blockchain as JSON |
| `GET` | `/health` | Chain validity and last save timestamp |
| `GET` | `/validate` | Chain validity, height, cumulative work, tip hash |
| `GET` | `/block/:index` | Single block by index |
| `GET` | `/mempool` | Pending transactions |
| `POST` | `/tx` | Body: signed `Transaction` JSON — validates and admits to mempool |
| `POST` | `/mine` | Body: `{ "miner_pubkey": "..." }` — mines coinbase + mempool txs |

`POST /tx` responses:

| Status | Condition |
|--------|-----------|
| 200 | Transaction accepted; returns `{ "txid": "..." }` |
| 400 | Invalid transaction structure, signature, balance, or fee |
| 401 | `HARPY_API_KEY` set but request lacks valid credentials |
| 409 | Double-spend conflict with mempool |
| 413 | JSON body exceeds 64 KiB (Kemal body limit) |
| 429 | Per-IP rate limit exceeded |

`POST /mine` responses:

| Status | Condition |
|--------|-----------|
| 200 | Block mined and appended |
| 400 | Missing/invalid `miner_pubkey` |
| 401 | `HARPY_API_KEY` set but request lacks valid credentials |
| 413 | JSON body exceeds 64 KiB |
| 422 | Mined block rejected by chain validation |
| 429 | Per-IP rate limit exceeded |

Default PoW difficulty: **3** leading zero hex digits (`Harpy::Block::DEFAULT_DIFFICULTY`). Override at genesis with `HARPY_DIFFICULTY` (see `docs/DEMO.md`). Difficulty retargets every 10 blocks toward a 60-second target interval.

### Environment variables

| Variable | Default | Scope |
|----------|---------|-------|
| `HARPY_DIFFICULTY` | `3` | Genesis only (ignored when `chain.json` exists) |
| `HARPY_DATA_DIR` | `data/chain.json` | Directory → `…/chain.json`, or a `.json` file path |
| `HARPY_API_KEY` | unset | When set, writes require `Authorization: Bearer` or `X-API-Key` |
| `HARPY_RATE_LIMIT` | `2` | Max mining requests per client per window |
| `HARPY_RATE_LIMIT_WINDOW` | `10` | Refill interval in seconds for the token bucket |
| `HARPY_TRUST_PROXY` | unset | When truthy, trust `X-Forwarded-For` for client identity (set only behind a trusted reverse proxy) |
| `HARPY_GENESIS_PUBKEY` | tutorial default | Ed25519 pubkey hex for genesis coinbase output |

Rate limiting applies to `POST /mine` and `POST /tx`. Client identity uses the first `X-Forwarded-For` hop **only when `HARPY_TRUST_PROXY` is set** (a directly-reachable node must not trust that client-supplied header); otherwise it uses the TCP remote address. Idle buckets are evicted once fully refilled to bound memory. See `docs/DEMO.md` for curl examples and `docs/THREAT_MODEL.md` for deployment guidance.

### Hash serialization

`Block#computed_hash` SHA-256 digests a canonical, **length-prefixed** encoding (domain tag `harpy-block-v2`) of `index`, `timestamp`, `merkle_root`, `prev_hash`, and `nonce` — each variable field prefixed by its byte length. **`difficulty` is not included.** Transaction bodies are committed via `merkle_root` only. Pinned vectors: `spec/fixtures/hash_vectors.json`.

Transaction `txid` and signing digest: SHA-256 over canonical JSON of `version`, `inputs` (without signatures), `outputs` (keys sorted lexicographically).

### Validation

Blocks must satisfy linkage, PoW prefix, hash integrity, and **monotonic timestamps** (child ≥ parent).

Fork replacement (`Chain#replace_if_more_work_valid!`) compares **cumulative PoW work** — each block contributes `16^difficulty` (`Block#work`) — not block count alone. Threat model: `docs/THREAT_MODEL.md`. Selfish-mining thresholds: `docs/SELFISH_MINING.md`. Confirmation depth: `docs/CONFIRMATION_DEPTH.md`.

## AI-assisted development security gates

When using AI coding agents on Harpy, follow these gates (from production-readiness research §4.3):

1. **Spec before code** — requirements and acceptance criteria live in Linear/issues and design docs (`docs/STATE_MODEL.md`, `docs/THREAT_MODEL.md`) *before* implementation. Tests verify correctness; they do not define it retroactively.
2. **SAST/SCA on AI-generated code** — run static analysis and dependency scanning on agent-produced diffs before merge (Crystal compiler warnings, `crystal tool format --check`, dependency audit).
3. **Independent review** — the session that generated a change must not be the sole reviewer. A human or adversarial second pass is required for merges touching consensus, crypto, or auth.
4. **Protected paths** — unreviewed AI output must not land in **authentication** (`config.cr` API key), **cryptography** (signatures, hashing), or **consensus** (fork choice, state transitions, difficulty retargeting) without explicit sign-off.

Link threat context: [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md). Harpy remains educational — these gates teach secure process, not production certification.

## Roadmap (from project research)

1. **Done (tutorial + hardening):** blocks, SHA-256, PoW, HTTP API, chain validation, cumulative-work fork choice, rate limits, write auth, request size caps
2. **Done (Phase 4):** UTXO state model, signed transactions (Ed25519), mempool, coinbase/fees, coinbase maturity, difficulty retargeting — see [docs/STATE_MODEL.md](docs/STATE_MODEL.md)
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

- Run the server: `crystal run src/harpy.cr` → listens on `http://localhost:3000` (`GET /`, `POST /tx`, `POST /mine`).
- Tests: `crystal spec`. Format: `crystal tool format[ --check]`. Build: `shards build` → `bin/harpy`.
