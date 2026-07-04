require "digest/sha256"
require "json"

module Harpy
  # The header fields that fully determine a block's PoW hash. Light clients can
  # sync and verify headers without downloading transaction bodies — the
  # `merkle_root` commits to the block's transactions, and (once anchoring lands)
  # `anchor_root` commits to externally-anchored record hashes.
  #
  # This struct owns the canonical hash preimage so `Block` and header-only
  # clients can never disagree on how a block hashes.
  struct BlockHeader
    include JSON::Serializable

    getter index : Int32
    getter timestamp : String
    getter merkle_root : String
    getter prev_hash : String
    getter difficulty : Int32
    getter nonce : String
    getter hash : String
    # Commitment to externally-anchored record hashes (MIC-81). Empty when the
    # block anchors nothing — in that case it is omitted from the hash preimage,
    # so pre-anchoring block hashes are unchanged (no version bump needed).
    getter anchor_root : String

    def initialize(
      @index : Int32,
      @timestamp : String,
      @merkle_root : String,
      @prev_hash : String,
      @difficulty : Int32,
      @nonce : String = "",
      @hash : String = "",
      @anchor_root : String = "",
    )
    end

    def computed_hash : String
      io = IO::Memory.new
      io << "harpy-block-v2\n"
      io << "index:" << @index << '\n'
      append_hash_field(io, "timestamp", @timestamp)
      append_hash_field(io, "merkle_root", @merkle_root)
      append_hash_field(io, "prev_hash", @prev_hash)
      append_hash_field(io, "nonce", @nonce)
      append_hash_field(io, "anchor_root", @anchor_root) unless @anchor_root.empty?

      Digest::SHA256.hexdigest(io.to_s)
    end

    private def append_hash_field(io : IO, label : String, value : String) : Nil
      io << label << ':' << value.bytesize << ':' << value << '\n'
    end

    def hash_matches? : Bool
      @hash == computed_hash
    end

    def pow_valid? : Bool
      return false if @difficulty < 0

      @hash.starts_with?("0" * @difficulty)
    end

    def work : UInt64
      return 1_u64 if @difficulty <= 0

      shift = 4 * @difficulty
      return UInt64::MAX if shift >= 64

      1_u64 << shift
    end
  end
end
