module Harpy
  module Storage
    # Contract every persistence backend implements. The free functions on the
    # `Storage` module delegate to a backend instance, so swapping the on-disk
    # representation (flat file today, an embedded KV store later) never touches
    # callers like `Server#chain`. See docs/STORAGE_BACKENDS.md for the KV spike.
    abstract class Backend
      # Load the persisted chain, or nil if nothing has been persisted yet.
      # Raises Harpy::StorageError on corruption (checksum mismatch, unparseable
      # data) — a failure mode distinct from semantic `Chain#valid?` checks.
      abstract def load : Chain?

      # Persist the chain durably. Implementations must be crash-safe: a failure
      # mid-write must not leave a partially written or corrupt store.
      abstract def save(chain : Chain) : Nil
    end
  end
end
