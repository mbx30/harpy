require "digest/sha256"
require "json"

module Harpy
  struct Block
    include JSON::Serializable

    DEFAULT_DIFFICULTY = 3

    getter index : Int32
    getter timestamp : String
    getter data : String
    getter hash : String
    getter prev_hash : String
    getter difficulty : Int32
    getter nonce : String

    def initialize(
      @index : Int32,
      @timestamp : String,
      @data : String,
      @prev_hash : String,
      @difficulty : Int32 = DEFAULT_DIFFICULTY,
      @nonce : String = "",
      @hash : String = "",
    )
    end

    # Canonical, injective preimage for the block hash. Every variable-length
    # field is length-prefixed (its UTF-8 byte count), so no field value — in
    # particular `data`, which is attacker-controlled and may contain arbitrary
    # bytes including newlines — can be crafted to reproduce the field layout of
    # a different block. The previous newline-joined format was ambiguous: a
    # `data` string containing newlines could forge a preimage identical to a
    # block with different timestamp/prev_hash/nonce, so the hash did not
    # uniquely commit to the structured contents.
    #
    # `difficulty` is intentionally excluded — it is a PoW validation threshold,
    # not part of block identity (see hash_vectors_spec). The `harpy-block-v2`
    # domain tag marks this format; the pre-v2 (v1) format is not accepted.
    def computed_hash : String
      io = IO::Memory.new
      io << "harpy-block-v2\n"
      io << "index:" << @index << '\n'
      append_hash_field(io, "timestamp", @timestamp)
      append_hash_field(io, "data", @data)
      append_hash_field(io, "prev_hash", @prev_hash)
      append_hash_field(io, "nonce", @nonce)

      Digest::SHA256.hexdigest(io.to_s)
    end

    private def append_hash_field(io : IO, label : String, value : String) : Nil
      io << label << ':' << value.bytesize << ':' << value << '\n'
    end

    def pow_valid? : Bool
      # A negative difficulty is nonsensical and would make `"0" * @difficulty`
      # raise (ArgumentError) mid-validation — a crafted chain file could crash
      # the loader. Reject it as invalid PoW instead. Difficulty 0 stays valid:
      # `"0" * 0 == ""` and every hash trivially satisfies it (lowest work tier).
      return false if @difficulty < 0

      @hash.starts_with?("0" * @difficulty)
    end

    # Expected hash trials for `difficulty` leading hex zeroes (16^difficulty),
    # saturating at UInt64::MAX. A raw `1_u64 << (4 * @difficulty)` wraps to 0
    # once the shift reaches 64 bits (difficulty ≥ 16), which would make a
    # maximally-hard block count as *zero* work and invert cumulative-work fork
    # choice. Saturating keeps work monotonically non-decreasing in difficulty.
    def work : UInt64
      return 1_u64 if @difficulty <= 0

      shift = 4 * @difficulty
      return UInt64::MAX if shift >= 64

      1_u64 << shift
    end

    def hash_matches? : Bool
      @hash == computed_hash
    end

    # Re-enforces the HTTP-layer cap (Config.max_block_data_bytes) so a block
    # loaded from storage, gossip, or a fork-choice replacement can't smuggle
    # an oversize payload past validation.
    def data_within_limit? : Bool
      @data.bytesize <= Config.max_block_data_bytes
    end

    def valid_against?(previous : Block) : Bool
      return false unless @index == previous.index + 1
      return false unless @prev_hash == previous.hash
      return false unless timestamp_not_before?(previous)
      return false unless hash_matches?
      return false unless pow_valid?
      return false unless data_within_limit?

      true
    end

    private def timestamp_not_before?(previous : Block) : Bool
      self_time = parse_timestamp(@timestamp)
      prev_time = parse_timestamp(previous.timestamp)
      self_time >= prev_time
    rescue Time::Format::Error
      false
    end

    private def parse_timestamp(value : String) : Time
      Time.parse(value, "%Y-%m-%d %H:%M:%S UTC", Time::Location::UTC)
    end

    def self.genesis(
      data : String = "Genesis block's data!",
      timestamp : String = Time.utc.to_s,
      difficulty : Int32 = DEFAULT_DIFFICULTY,
    ) : Block
      new(0, timestamp, data, "", difficulty)
    end
  end
end
