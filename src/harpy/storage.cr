require "json"
require "digest/sha256"
require "./config"

module Harpy
  class StorageError < Exception; end

  module Storage
    extend self

    DEFAULT_PATH = "data/chain.json"

    # Bump when the on-disk envelope schema changes. Add a
    # `migrate_v#{CURRENT_VERSION - 1}_to_v#{CURRENT_VERSION}` and dispatch to
    # it from `load` alongside the existing `migrate_v1_to_v2`.
    CURRENT_VERSION = 2

    private struct Envelope
      include JSON::Serializable

      getter version : Int32
      getter checksum : String
      getter blocks : Array(Block)

      def initialize(@version : Int32, @checksum : String, @blocks : Array(Block))
      end
    end

    # Checksum depends on `Block`'s getter declaration order (JSON::Serializable
    # serializes fields in declaration order). Do not reorder Block's getters
    # without a version bump — it would silently break existing checksums.
    private def compute_checksum(blocks : Array(Block)) : String
      Digest::SHA256.hexdigest(blocks.to_json)
    end

    # v1 is the historical bare-array `chain.json` format (no envelope, no
    # checksum, no version) — everything written before this change.
    private def migrate_v1_to_v2(bare_blocks : Array(Block)) : Envelope
      Envelope.new(CURRENT_VERSION, compute_checksum(bare_blocks), bare_blocks)
    end

    def load(path : String = DEFAULT_PATH) : Chain?
      return nil unless File.exists?(path)

      raw = File.read(path)
      json = JSON.parse(raw)

      envelope =
        case json.raw
        when Array
          migrate_v1_to_v2(Array(Block).from_json(raw))
        when Hash
          Envelope.from_json(raw)
        else
          raise StorageError.new("chain file is not a valid chain document")
        end

      unless envelope.version == CURRENT_VERSION
        raise StorageError.new("unsupported chain storage version #{envelope.version} (expected #{CURRENT_VERSION})")
      end

      unless compute_checksum(envelope.blocks) == envelope.checksum
        raise StorageError.new("chain file checksum mismatch (possible corruption or tampering)")
      end

      Chain.new(envelope.blocks)
    rescue ex : JSON::Error
      raise StorageError.new("chain file is not valid JSON: #{ex.message}")
    end

    def save(chain : Chain, path : String = DEFAULT_PATH) : Nil
      dir = File.dirname(path)
      Dir.mkdir_p(dir)

      envelope = Envelope.new(CURRENT_VERSION, compute_checksum(chain.blocks), chain.blocks)

      tmp_path = File.tempname("chain", ".json.tmp", dir: dir)
      File.open(tmp_path, "w") do |file|
        file.print(envelope.to_json)
        file.flush
        file.fsync
      end
      File.rename(tmp_path, path)
    end

    def load_or_genesis(path : String = DEFAULT_PATH, verbose : Bool = false) : Chain
      if chain = load(path)
        raise StorageError.new("stored chain failed validation") unless chain.valid?

        chain
      else
        chain = Chain.genesis_chain(difficulty: Config.genesis_difficulty, verbose: verbose)
        save(chain, path)
        chain
      end
    end
  end
end
