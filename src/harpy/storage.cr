require "json"
require "digest/sha256"
require "log"
require "./config"
require "./storage/backend"
require "./storage/file_backend"

module Harpy
  class StorageError < Exception; end

  module Storage
    extend self

    Log = ::Log.for("harpy.storage")

    DEFAULT_PATH = "data/chain.json"

    # On-disk envelope: a SHA-256 over the canonical `blocks.to_json` alongside
    # the blocks themselves. The checksum lets a backend detect bit-rot,
    # truncation, or manual edits before any Chain is constructed — a corruption
    # check distinct from the semantic `Chain#valid?` check that runs afterward.
    struct Envelope
      include JSON::Serializable

      getter checksum : String
      getter blocks : Array(Block)

      def initialize(@checksum : String, @blocks : Array(Block))
      end

      def self.wrap(blocks : Array(Block)) : Envelope
        new(Digest::SHA256.hexdigest(blocks.to_json), blocks)
      end

      def checksum_valid? : Bool
        Digest::SHA256.hexdigest(@blocks.to_json) == @checksum
      end
    end

    # The backend the free functions delegate to for a given path. Isolated here
    # so a future KV backend is a one-line swap (see docs/STORAGE_BACKENDS.md).
    def backend_for(path : String) : Backend
      FileBackend.new(path)
    end

    def load(path : String = DEFAULT_PATH) : Chain?
      backend_for(path).load
    end

    def save(chain : Chain, path : String = DEFAULT_PATH) : Nil
      backend_for(path).save(chain)
    end

    def load_or_genesis(path : String = DEFAULT_PATH, verbose : Bool = false) : Chain
      backend = backend_for(path)

      if chain = backend.load
        unless chain.valid?
          Log.error { "chain_load_failed path=#{path} reason=validation_failed" }
          raise StorageError.new("stored chain failed validation")
        end

        chain
      else
        chain = Chain.genesis_chain(difficulty: Config.genesis_difficulty, verbose: verbose)
        backend.save(chain)
        chain
      end
    end
  end
end
