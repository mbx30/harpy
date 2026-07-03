# harpy

A Crystal proof-of-work blockchain tutorial. Named after Harpocrates, the Greek god of silence.

**Linear:** [harpy project](https://linear.app/mbx2/project/harpy-16c5704dd57d/overview)

This is an educational, single-node chain — blocks linked by SHA-256, mined with a simple proof-of-work algorithm, exposed over HTTP. It is not a production blockchain.

## Prerequisites (Windows)

1. Install Crystal: `winget install CrystalLang.Crystal`
2. **Enable Developer Mode** (required for `shards` symlinks):
   - Run `start ms-settings:developers`
   - Turn on **Developer Mode**
3. **Restart your terminal** (or Cursor) so `crystal` and `shards` are on PATH

Crystal installs to `%LOCALAPPDATA%\Programs\crystal`. If commands aren't found in an already-open terminal:

```powershell
$env:Path = "$env:LOCALAPPDATA\Programs\crystal;$env:Path"
```

Or run the setup script:

```powershell
.\scripts\setup.ps1
```

## Getting started

```powershell
shards install
crystal run src/harpy.cr
```

- **View chain:** `GET http://localhost:3000/`
- **Validate chain:** `GET http://localhost:3000/validate`
- **Get block by index:** `GET http://localhost:3000/block/:index`
- **Mine a block:** `POST http://localhost:3000/new-block` with JSON body `{ "data": "your block data" }`

The chain is persisted to `data/chain.json` on startup and after each mined block (override with `HARPY_DATA_DIR`).

### Configuration (environment)

| Variable | Purpose |
|----------|---------|
| `HARPY_DIFFICULTY` | Genesis PoW difficulty (only when creating a new chain) |
| `HARPY_DATA_DIR` | Chain file path or parent directory (default `data/chain.json`) |
| `HARPY_API_KEY` | Optional write auth for `POST /new-block` |
| `HARPY_RATE_LIMIT` | Max mining requests per client per window (default `2`) |
| `HARPY_RATE_LIMIT_WINDOW` | Token-bucket refill interval in seconds (default `10`) |

Example — faster genesis for local demos:

```bash
rm -f data/chain.json
HARPY_DIFFICULTY=1 crystal run src/harpy.cr
```

Example — staging with write auth and tighter rate limits:

```bash
HARPY_API_KEY=change-me HARPY_RATE_LIMIT=1 HARPY_RATE_LIMIT_WINDOW=30 crystal run src/harpy.cr
```

See **[docs/DEMO.md](docs/DEMO.md)** for the full walkthrough, curl examples, auth headers, difficulty table, and testing steps.

Security posture for the open HTTP mining API is documented in **[docs/THREAT_MODEL.md](docs/THREAT_MODEL.md)** (layer taxonomy, assets, threat catalog, Linear issue mapping).

## Development

```bash
crystal spec                 # run tests
crystal tool format          # format source
shards build                 # build bin/harpy
```

## Project layout

```
src/harpy.cr           # entry point
src/harpy/block.cr     # Block struct, SHA-256 hashing, validation
src/harpy/chain.cr     # in-memory chain, append, fork replacement
src/harpy/config.cr    # env config, size limits, write auth
src/harpy/miner.cr     # proof-of-work mining loop
src/harpy/rate_limit.cr # per-IP token bucket on POST /new-block
src/harpy/storage.cr   # JSON load/save, genesis bootstrap
src/harpy/server.cr    # Kemal HTTP routes
docs/                  # DEMO.md, THREAT_MODEL.md, STATE_MODEL.md
spec/                  # tests + fixtures/hash_vectors.json
data/chain.json        # persisted chain (created at runtime)
```

## Roadmap

1. Tutorial + hardening: PoW blocks, HTTP API, validation, rate limits, write auth (current)
2. State model — [UTXO design](docs/STATE_MODEL.md) (Phase 5 blocked until approved)
3. P2P networking and reorg handling
4. Adjustable difficulty retargeting
5. Merkle anchoring API (hash on-chain, payload off-chain)

See [AGENTS.md](./AGENTS.md) for agent-oriented guidance and references.
