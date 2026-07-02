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
- **Mine a block:** `POST http://localhost:3000/new-block` with JSON body `{ "data": "your block data" }`

## Development

```bash
crystal spec                 # run tests
crystal tool format          # format source
shards build                 # build bin/harpy
```

## Project layout

```
src/harpy.cr           # entry point
src/harpy/block.cr     # hashing, mining, validation
src/harpy/chain.cr     # in-memory chain
src/harpy/server.cr    # Kemal HTTP routes
spec/                  # tests
```

## Roadmap

1. Tutorial scope (current): PoW blocks + HTTP API
2. Chain validation and fork selection
3. State model (UTXO or accounts)
4. P2P networking and reorg handling
5. Persistent storage and adjustable difficulty

See [AGENTS.md](./AGENTS.md) for agent-oriented guidance and references.
