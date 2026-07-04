require "digest/sha256"
require "json"
require "./block_header"

module Harpy
  # Union type for block transaction list entries.
  alias BlockTx = Transaction | CoinbaseTx

  struct Block
    include JSON::Serializable

    DEFAULT_DIFFICULTY = 3

    getter index : Int32
    getter timestamp : String
    getter transactions : Array(BlockTx)
    getter merkle_root : String
    getter hash : String
    getter prev_hash : String
    getter difficulty : Int32
    getter nonce : String
    # Optional commitment to externally-anchored record hashes (MIC-81).
    getter anchor_root : String

    def initialize(
      @index : Int32,
      @timestamp : String,
      @transactions : Array(BlockTx),
      @prev_hash : String,
      @difficulty : Int32 = DEFAULT_DIFFICULTY,
      @nonce : String = "",
      @hash : String = "",
      @merkle_root : String = "",
      @anchor_root : String = "",
    )
      @merkle_root = @merkle_root.empty? ? compute_merkle_root : @merkle_root
    end

    def compute_merkle_root : String
      Merkle.root(@transactions.map(&.txid))
    end

    # Header view carrying exactly the PoW-committed fields. The header owns the
    # canonical hash preimage so full blocks and header-only light clients agree.
    def header : BlockHeader
      BlockHeader.new(@index, @timestamp, @merkle_root, @prev_hash, @difficulty, @nonce, @hash, @anchor_root)
    end

    def computed_hash : String
      header.computed_hash
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

    def hash_matches? : Bool
      @hash == computed_hash
    end

    def transactions_within_limit? : Bool
      user_count = @transactions.size > 0 ? @transactions.size - 1 : 0
      return false if user_count > Economics::MAX_TXS_PER_BLOCK

      serialized = @transactions.to_json
      serialized.bytesize <= Config.max_block_transactions_bytes
    end

    def valid_against?(previous : Block, utxo_set : UtxoSet, expected_difficulty : Int32) : Bool
      return false unless @index == previous.index + 1
      return false unless @prev_hash == previous.hash
      return false unless @difficulty == expected_difficulty
      return false unless timestamp_not_before?(previous)
      return false unless hash_matches?
      return false unless pow_valid?
      return false unless transactions_within_limit?
      return false unless @transactions.first?.try &.is_a?(CoinbaseTx)
      return false unless State.validate_block_transactions(self, utxo_set.dup_set)

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
      miner_pubkey : String = Economics.genesis_pubkey,
      timestamp : String = Time.utc.to_s,
      difficulty : Int32 = DEFAULT_DIFFICULTY,
    ) : Block
      coinbase = CoinbaseTx.new(
        outputs: [TxOutput.new(Economics::BLOCK_REWARD, miner_pubkey)],
        height: 0_u32,
      )
      new(0, timestamp, [coinbase] of BlockTx, "", difficulty)
    end

    # Custom JSON for polymorphic transaction array.
    def self.from_json(json : JSON::Any) : Block
      obj = json.as_h
      txs = obj["transactions"].as_a.map { |entry| parse_block_tx(entry) }
      new(
        obj["index"].as_i.to_i32,
        obj["timestamp"].as_s,
        txs,
        obj["prev_hash"].as_s,
        obj["difficulty"]?.try(&.as_i.to_i32) || DEFAULT_DIFFICULTY,
        obj["nonce"]?.try(&.as_s) || "",
        obj["hash"]?.try(&.as_s) || "",
        obj["merkle_root"]?.try(&.as_s) || "",
        obj["anchor_root"]?.try(&.as_s) || "",
      )
    end

    def self.parse_block_tx(json : JSON::Any) : BlockTx
      obj = json.as_h
      if obj["height"]?
        CoinbaseTx.from_json(json.to_json)
      else
        Transaction.from_json(json.to_json)
      end
    end
  end
end
