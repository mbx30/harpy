# Storage backends

Harpy persists the chain behind a small backend interface so the on-disk
representation can change without touching callers. This document describes the
interface and records the embedded-KV spike (MIC-49).

## Interface

`Harpy::Storage::Backend` ([backend.cr](../src/harpy/storage/backend.cr)) is an
abstract class with two methods:

```crystal
abstract def load : Chain?          # nil if nothing persisted; raises StorageError on corruption
abstract def save(chain : Chain)    # crash-safe durable write
```

The `Harpy::Storage` module ([storage.cr](../src/harpy/storage.cr)) is a thin
facade: `Storage.load`, `Storage.save`, and `Storage.load_or_genesis` build a
backend via `Storage.backend_for(path)` and delegate. Callers such as
`Server#chain` (`Storage.load_or_genesis(@@storage_path)`) are unaffected by
which backend is in use.

### FileBackend (default)

`Harpy::Storage::FileBackend` ([file_backend.cr](../src/harpy/storage/file_backend.cr))
is the only backend today. It stores the chain as a single JSON file wrapping a
**versioned checksum envelope** (`Storage::Envelope`:
`{format_version, checksum, blocks}`), where `format_version` is `3` and
`checksum` is `SHA-256(blocks.to_json)`.

- **Atomic writes (MIC-39):** writes go to a sibling `<path>.tmp` in the same
  directory, then `File.rename` over the target — atomic on one filesystem, so a
  crash mid-write cannot leave a partial file.
- **Checksum verification (MIC-48):** `load` recomputes the checksum and raises
  `Harpy::StorageError` on mismatch *before* constructing a `Chain`, catching
  bit-rot / truncation / manual edits. This is distinct from the semantic
  `Chain#valid?` check that runs afterward in `load_or_genesis`.
- **Consensus reset:** v2 envelopes and legacy bare arrays are rejected with an
  explicit `harpy-block-v3` reset message. There is no compatibility migration.

## Embedded KV spike (MIC-49) — findings & recommendation

**Question:** should Harpy swap the flat file for an embedded key-value store
(e.g. SQLite) as the default or an optional backend?

**Findings (verified on this Windows dev environment, 2026-07):**

- Crystal's standard library ships **no** embedded KV / database engine — a
  scan of the stdlib source found no sqlite/lmdb/dbm module. Any KV backend
  requires an external shard.
- The community `crystal-sqlite3` shard links against a system `sqlite3`
  (`@[Link("sqlite3")]`). On this machine:
  - `winsqlite3.dll` exists in `System32`, but there is **no** `sqlite3.lib`
    import library, **no** `pkg-config` entry for sqlite3, and **no** `sqlite3`
    CLI on PATH.
  - Under MSVC that means the shard would **not** link cleanly without manually
    building the SQLite amalgamation into an import library and wiring headers —
    a real setup cost, and a per-contributor one on Windows.
- Adding such a shard to `shard.yml` now would risk breaking `shards build` /
  CI for anyone without that native dependency configured — a poor trade for a
  single-node tutorial whose chains are small JSON files.

**Recommendation: defer the KV backend; keep FileBackend as the default.**

The valuable, low-risk half of MIC-49 — the backend interface — is implemented,
so a KV backend becomes a drop-in addition when a concrete need arises
(datasets too large for whole-file rewrite, or concurrent readers). When that
happens:

1. Add a maintained KV shard, pinned to a release compatible with the Crystal
   version in [shard.yml](../shard.yml); confirm `shards install` **and** a
   trial `shards build` succeed on Linux/macOS/Windows before committing.
2. Implement `Harpy::Storage::KvBackend < Storage::Backend` (store the same
   checksum envelope, or per-block rows keyed by index with a chain-level
   checksum record).
3. Make `Storage.backend_for` select the backend from config — mirror the
   existing `HARPY_DATA_DIR` env pattern in [config.cr](../src/harpy/config.cr)
   with a `HARPY_STORAGE_BACKEND` variable (`file` default, `kv` opt-in).
4. Reuse the existing `describe Harpy::Storage::FileBackend` spec shape for a
   `KvBackend` block so both backends prove the same round-trip / corruption
   behavior through the interface.
