# Harpy storage backends

Chain persistence sits behind a small `Harpy::Storage::Backend` interface so the on-disk representation can change without touching HTTP handlers or P2P code.

## Current implementation: `FileBackend`

The default backend writes a single JSON file (`HARPY_DATA_DIR`, default `data/chain.json`):

```json
{
  "checksum": "<sha256 of serialized blocks>",
  "blocks": [ /* Block array */ ]
}
```

| Property | Behavior |
|----------|----------|
| **Atomic writes** | Data written to `chain.json.tmp`, then renamed over the target |
| **Checksum** | SHA-256 over the blocks payload; mismatch raises `StorageError` on load |
| **Legacy format** | Bare JSON arrays still load (with a warning) for pre-envelope chains |
| **UTXO set** | Not persisted separately — rebuilt by replaying blocks on boot |

Free functions on `Harpy::Storage` (`load`, `save`, `load_or_genesis`) delegate to a `FileBackend` instance. Callers like `Server#chain` and `P2p::Network` use these entry points only.

## Backend contract

```crystal
abstract class Harpy::Storage::Backend
  abstract def load : Chain?
  abstract def save(chain : Chain) : Nil
end
```

- `load` returns `nil` when no file exists (triggers genesis bootstrap).
- `load` raises `StorageError` on corruption (checksum, parse errors) — distinct from semantic `Chain#valid?` failures.
- `save` must be crash-safe: a failed write must not leave a partial file.

## CLI and operations

```bash
crystal run src/harpy.cr -- verify-chain --path data/chain.json
crystal run src/harpy.cr -- export-chain --path data/chain.json --out backup.json
```

`verify-chain` exercises load + `Chain#valid?` and exits non-zero on failure — suitable for CI and post-restore checks.

## Future: embedded KV backend

A future milestone may swap `FileBackend` for an embedded key-value store (RocksDB/LMDB equivalent) to support:

- Faster random access by block hash or height
- Separate UTXO snapshot keys (optional optimization)
- Online compaction without rewriting the full chain array

Until that lands, the file backend is sufficient for tutorial scale. Multi-node operators should give each node its own `HARPY_DATA_DIR` path and back up chain files independently.

## Related documents

- [DEMO.md](./DEMO.md) — `HARPY_DATA_DIR`, durability notes
- [INCIDENT_RESPONSE.md](./INCIDENT_RESPONSE.md) — backup and rollback guidance
