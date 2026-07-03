# harpy

A Crystal proof-of-work blockchain tutorial. Named after Harpocrates, the Greek god of silence.

**Linear:** [harpy project](https://linear.app/mbx2/project/harpy-16c5704dd57d/overview)

Educational PoW chain with UTXO transactions, HTTP API, optional P2P block gossip, and cumulative-work reorgs. Not production blockchain software.

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

```bash
shards install
crystal run src/harpy.cr
```

| Endpoint | Description |
|----------|-------------|
| `GET /` | Full blockchain JSON |
| `GET /health` | Chain validity, save timestamp, P2P status |
| `GET /validate` | Validity, height, cumulative work, tip hash |
| `GET /block/:index` | Single block |
| `GET /mempool` | Pending transactions |
| `POST /tx` | Submit signed transaction (mempool) |
| `POST /mine` | Mine block with `{ "miner_pubkey": "..." }` |

The chain persists to `data/chain.json` (override with `HARPY_DATA_DIR`). Writes are atomic with a SHA-256 checksum envelope — see **[docs/STORAGE_BACKENDS.md](docs/STORAGE_BACKENDS.md)**.

### CLI

```bash
crystal run src/harpy.cr -- verify-chain --path data/chain.json
crystal run src/harpy.cr -- export-chain --path data/chain.json --out backup.json
crystal run src/harpy.cr -- help
```

### Configuration (environment)

| Variable | Purpose |
|----------|---------|
| `HARPY_DIFFICULTY` | Genesis PoW difficulty (new chain only) |
| `HARPY_DATA_DIR` | Chain file path or parent directory |
| `HARPY_API_KEY` | Optional write auth for `POST /tx` and `POST /mine` |
| `HARPY_RATE_LIMIT` | Max write requests per client per window (default `2`) |
| `HARPY_RATE_LIMIT_WINDOW` | Token-bucket refill interval in seconds (default `10`) |
| `HARPY_BIND_HOST` | HTTP bind address (default `127.0.0.1`) |
| `HARPY_HTTP_PORT` / `PORT` | HTTP port (default `3000`) |
| `HARPY_TRUST_PROXY` | Trust `X-Forwarded-For` for rate limiting (trusted proxy only) |
| `HARPY_P2P_DISABLE` | Set `1` to disable P2P |
| `HARPY_P2P_PORT` | P2P TCP port (default `9333`) |
| `HARPY_P2P_PEERS` | Comma-separated bootstrap peers |
| `HARPY_ANCHOR_PEERS` | Trusted peers for eclipse countermeasures |

Example — local demo with faster genesis:

```bash
rm -f data/chain.json
HARPY_DIFFICULTY=1 crystal run src/harpy.cr
```

Example — multi-node on one host:

```bash
HARPY_DATA_DIR=/tmp/node-a.json HARPY_HTTP_PORT=3000 HARPY_P2P_PORT=9333 crystal run src/harpy.cr
HARPY_DATA_DIR=/tmp/node-b.json HARPY_HTTP_PORT=3001 HARPY_P2P_PORT=9334 \
  HARPY_P2P_PEERS=127.0.0.1:9333 crystal run src/harpy.cr
```

See **[docs/DEMO.md](docs/DEMO.md)** for curl walkthroughs and **[docs/P2P.md](docs/P2P.md)** for gossip, reorgs, and troubleshooting.

Security posture: **[docs/THREAT_MODEL.md](docs/THREAT_MODEL.md)**.

## Development

```bash
crystal spec
crystal tool format
shards build
```

## Project layout

```
src/harpy.cr                    # entry point → CLI dispatch
src/harpy/                      # block, chain, state, mempool, miner, storage, server
src/harpy/p2p/                  # gossip, protocol, orphan pool, peer manager
docs/                           # DEMO, P2P, STATE_MODEL, THREAT_MODEL, STORAGE_BACKENDS, …
spec/                           # tests + fixtures/hash_vectors.json
```

## Roadmap

1. **Done:** PoW blocks, UTXO transactions, HTTP API, validation, rate limits, write auth
2. **Done:** P2P gossip, orphan pool, cumulative-work reorgs — [docs/P2P.md](docs/P2P.md)
3. **Done:** Atomic storage, checksum envelope — [docs/STORAGE_BACKENDS.md](docs/STORAGE_BACKENDS.md)
4. Optional: embedded KV backend; Merkle anchoring API (MIC-81)

See [AGENTS.md](./AGENTS.md) for agent-oriented guidance.
