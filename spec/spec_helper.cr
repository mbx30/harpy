require "spec"
require "../src/harpy/*"

module Harpy::SpecHelpers
  def self.mined_genesis(difficulty : Int32 = 0, miner_pubkey : String = Harpy::Economics.genesis_pubkey) : Harpy::Block
    Harpy::Miner.mine(Harpy::Block.genesis(miner_pubkey: miner_pubkey, difficulty: difficulty))
  end

  def self.generate_keypair
    Harpy::Crypto.generate_keypair
  end

  def self.build_spend_tx(
    outpoint : Harpy::OutPoint,
    input_amount : UInt64,
    signing_key : Ed25519::SigningKey,
    to_pubkey : String,
    send_amount : UInt64,
    fee : UInt64 = Harpy::Economics::MIN_TX_FEE,
  ) : Harpy::Transaction
    change = input_amount - send_amount - fee
    outputs = [Harpy::TxOutput.new(send_amount, to_pubkey)]
    outputs << Harpy::TxOutput.new(change, Harpy::Crypto.pubkey_hex(signing_key.verify_key)) if change > 0

    Harpy::Transaction.new(
      inputs: [Harpy::TxInput.new(outpoint)],
      outputs: outputs,
    ).sign_all(signing_key)
  end

  def self.build_chain(
    block_count : Int32,
    difficulty : Int32 = 0,
    miner_pubkey : String = Harpy::Economics.genesis_pubkey,
  ) : Harpy::Chain
    chain = Harpy::Chain.new([mined_genesis(difficulty, miner_pubkey)])

    (1...block_count).each do |_index|
      block = Harpy::Miner.mine_from_mempool(chain, miner_pubkey, verbose: false)
      chain.append!(block).should be_true
    end

    chain
  end

  def self.with_env(key : String, value : String?, &)
    previous = ENV[key]?
    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end

    begin
      yield
    ensure
      if previous.nil?
        ENV.delete(key)
      else
        ENV[key] = previous
      end
    end
  end

  TAMPER_FIELDS = %w(index timestamp merkle_root prev_hash difficulty nonce hash)

  def self.tamper_block(block : Harpy::Block, field : String) : Harpy::Block
    case field
    when "index"
      Harpy::Block.new(block.index + 1, block.timestamp, block.transactions, block.prev_hash, block.difficulty, block.nonce, block.hash, block.merkle_root)
    when "timestamp"
      Harpy::Block.new(block.index, "1970-01-01 00:00:00 UTC", block.transactions, block.prev_hash, block.difficulty, block.nonce, block.hash, block.merkle_root)
    when "merkle_root"
      Harpy::Block.new(block.index, block.timestamp, block.transactions, block.prev_hash, block.difficulty, block.nonce, block.hash, "deadbeef" * 8)
    when "prev_hash"
      Harpy::Block.new(block.index, block.timestamp, block.transactions, "deadbeef", block.difficulty, block.nonce, block.hash, block.merkle_root)
    when "difficulty"
      Harpy::Block.new(block.index, block.timestamp, block.transactions, block.prev_hash, block.difficulty + 1, block.nonce, "deadbeef", block.merkle_root)
    when "nonce"
      Harpy::Block.new(block.index, block.timestamp, block.transactions, block.prev_hash, block.difficulty, "ffff", block.hash, block.merkle_root)
    when "hash"
      Harpy::Block.new(block.index, block.timestamp, block.transactions, block.prev_hash, block.difficulty, block.nonce, "deadbeef", block.merkle_root)
    else
      raise "unknown field: #{field}"
    end
  end

  def self.extend_fork_from(
    genesis : Harpy::Block,
    block_count : Int32,
    label : String = "fork",
    difficulty : Int32? = nil,
    miner_pubkey : String = Harpy::Economics.genesis_pubkey,
  ) : Harpy::Chain
    fork = Harpy::Chain.new([genesis])
    (1...block_count).each do |_index|
      block_difficulty = difficulty || fork.tip.difficulty
      next_height = (fork.tip.index + 1).to_u32
      coinbase = Harpy::CoinbaseTx.new(
        outputs: [Harpy::TxOutput.new(Harpy::Economics::BLOCK_REWARD, miner_pubkey)],
        height: next_height,
      )
      candidate = Harpy::Block.new(
        fork.tip.index + 1,
        Time.utc.to_s,
        [coinbase] of Harpy::BlockTx,
        fork.tip.hash,
        block_difficulty,
      )
      fork.append!(Harpy::Miner.mine(candidate)).should be_true
    end
    fork
  end
end
