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
    types.cr            # Harpy::VERSION + Harpy::BlockType
    block.cr            # Create, hash, mine (PoW), validate blocks
    chain.cr            # In-memory blockchain (genesis + append)
    server.cr           # GET / and POST /new-block
```

### HTTP API

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Return full blockchain as JSON |
| `POST` | `/new-block` | Body: `{ "data": "..." }` — mines and appends a block |

Default PoW difficulty: **3** leading zero hex digits (`Harpy::Block::DEFAULT_DIFFICULTY`).

## Roadmap (from project research)

1. **Now:** blocks + SHA-256 + PoW + HTTP endpoints (tutorial scope)
2. Harden validation — full chain validation, longest-valid-chain selection
3. Pick a state model — UTXO vs accounts (design before coding)
4. P2P networking — gossip, orphan pool, fork choice, reorgs
5. Persistent storage — embedded KV (RocksDB/LMDB equivalent)
6. Adjustable difficulty — retarget from observed block times
7. Optional: minimal VM with gas metering

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
