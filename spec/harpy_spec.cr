require "./spec_helper"

describe Harpy::Block do
  it "has a version" do
    Harpy::VERSION.should eq("0.1.0")
  end

  it "computes a deterministic hash from merkle_root" do
    block = Harpy::Block.genesis(difficulty: 0)
    hash = block.computed_hash

    hash.size.should eq(64)
    Harpy::Block.genesis(difficulty: 0).computed_hash.should eq(hash)
  end

  it "validates proof-of-work difficulty" do
    Harpy::Block.new(0, "2026-01-01", Harpy::Block.genesis(difficulty: 0).transactions, "", 3, "0", "000abc").pow_valid?.should be_true
    Harpy::Block.new(0, "2026-01-01", Harpy::Block.genesis(difficulty: 0).transactions, "", 3, "0", "00abc").pow_valid?.should be_false
  end

  it "treats a negative difficulty as invalid PoW instead of raising" do
    Harpy::Block.new(0, "2026-01-01", Harpy::Block.genesis(difficulty: 0).transactions, "", -1, "0", "abc").pow_valid?.should be_false
  end

  it "commits to merkle_root injectively in the hash preimage" do
    genesis = Harpy::Block.genesis(difficulty: 0)
    other = Harpy::Block.new(0, genesis.timestamp, genesis.transactions, "", 0, "x", "", "different" * 8)

    genesis.computed_hash.should_not eq(other.computed_hash)
  end

  it "saturates work instead of overflowing to zero at high difficulty" do
    txs = Harpy::Block.genesis(difficulty: 0).transactions
    Harpy::Block.new(0, "2026-01-01", txs, "", 16, "0").work.should eq(UInt64::MAX)
    Harpy::Block.new(0, "2026-01-01", txs, "", 15, "0").work.should eq(1_u64 << 60)
    Harpy::Block.new(0, "2026-01-01", txs, "", 0, "0").work.should eq(1_u64)
  end

  it "validates linkage and hash integrity against the previous block" do
    chain = Harpy::SpecHelpers.build_chain(2)
    expected = Harpy::Difficulty.required_for_block([chain.blocks.first])
    chain.blocks.last.valid_against?(chain.blocks.first, chain.utxo_set, expected).should be_true
  end

  it "rejects a block whose difficulty does not match retarget expectations" do
    chain = Harpy::SpecHelpers.build_chain(1, difficulty: 3)
    genesis = chain.blocks.first
    coinbase = Harpy::CoinbaseTx.new(
      outputs: [Harpy::TxOutput.new(Harpy::Economics::BLOCK_REWARD, Harpy::Economics.genesis_pubkey)],
      height: 1_u32,
    )
    wrong_difficulty = Harpy::Miner.mine(
      Harpy::Block.new(1, Time.utc.to_s, [coinbase] of Harpy::BlockTx, genesis.hash, 0),
    )

    chain.append!(wrong_difficulty).should be_false
    chain.height.should eq(1)
  end

  it "rejects blocks with a tampered hash" do
    chain = Harpy::SpecHelpers.build_chain(2)
    genesis = chain.blocks.first
    next_block = chain.blocks.last
    expected = Harpy::Difficulty.required_for_block([genesis])
    tampered = Harpy::Block.new(
      next_block.index,
      next_block.timestamp,
      next_block.transactions,
      next_block.prev_hash,
      next_block.difficulty,
      next_block.nonce,
      "deadbeef",
      next_block.merkle_root,
    )

    tampered.valid_against?(genesis, chain.utxo_set, expected).should be_false
  end

  it "accepts a child block with the same timestamp as its parent" do
    genesis = Harpy::SpecHelpers.mined_genesis
    expected = Harpy::Difficulty.required_for_block([genesis])
    coinbase = Harpy::CoinbaseTx.new(
      outputs: [Harpy::TxOutput.new(Harpy::Economics::BLOCK_REWARD, Harpy::Economics.genesis_pubkey)],
      height: 1_u32,
    )
    same_time = Harpy::Miner.mine(
      Harpy::Block.new(1, genesis.timestamp, [coinbase] of Harpy::BlockTx, genesis.hash, genesis.difficulty),
    )

    chain = Harpy::Chain.new([genesis])
    same_time.valid_against?(genesis, chain.utxo_set, expected).should be_true
  end

  it "rejects a child block with a timestamp before its parent" do
    genesis = Harpy::SpecHelpers.mined_genesis
    expected = Harpy::Difficulty.required_for_block([genesis])
    coinbase = Harpy::CoinbaseTx.new(
      outputs: [Harpy::TxOutput.new(Harpy::Economics::BLOCK_REWARD, Harpy::Economics.genesis_pubkey)],
      height: 1_u32,
    )
    backdated = Harpy::Miner.mine(
      Harpy::Block.new(1, "2020-01-01 00:00:00 UTC", [coinbase] of Harpy::BlockTx, genesis.hash, genesis.difficulty),
    )

    chain = Harpy::Chain.new([genesis])
    backdated.valid_against?(genesis, chain.utxo_set, expected).should be_false
  end
end

describe Harpy::Chain do
  it "validates a mined chain end to end" do
    chain = Harpy::SpecHelpers.build_chain(3)

    chain.valid?.should be_true
    chain.height.should eq(3)
  end

  it "rejects blocks that do not link to the tip" do
    chain = Harpy::SpecHelpers.build_chain(2)
    coinbase = Harpy::CoinbaseTx.new(
      outputs: [Harpy::TxOutput.new(Harpy::Economics::BLOCK_REWARD, Harpy::Economics.genesis_pubkey)],
      height: 99_u32,
    )
    orphan = Harpy::Miner.mine(Harpy::Block.new(99, Time.utc.to_s, [coinbase] of Harpy::BlockTx, "missing", 0))

    chain.append!(orphan).should be_false
    chain.height.should eq(2)
  end

  it "rejects appending a block with a regressive timestamp" do
    chain = Harpy::SpecHelpers.build_chain(2)
    tip = chain.tip
    coinbase = Harpy::CoinbaseTx.new(
      outputs: [Harpy::TxOutput.new(Harpy::Economics::BLOCK_REWARD, Harpy::Economics.genesis_pubkey)],
      height: (tip.index + 1).to_u32,
    )
    backdated = Harpy::Miner.mine(
      Harpy::Block.new(tip.index + 1, "2020-01-01 00:00:00 UTC", [coinbase] of Harpy::BlockTx, tip.hash, tip.difficulty),
    )

    chain.append!(backdated).should be_false
    chain.height.should eq(2)
  end

  it "replaces the chain only with a valid candidate that has more cumulative work" do
    chain = Harpy::SpecHelpers.build_chain(2)
    longer = Harpy::SpecHelpers.build_chain(3)

    chain.replace_if_more_work_valid!(longer.blocks).should be_true
    chain.height.should eq(3)

    shorter = Harpy::SpecHelpers.build_chain(2)
    chain.replace_if_more_work_valid!(shorter.blocks).should be_false
    chain.height.should eq(3)
  end

  it "sums cumulative work as 16^difficulty per block" do
    chain = Harpy::SpecHelpers.build_chain(3, difficulty: 2)

    chain.cumulative_work.should eq(3_u64 * (1_u64 << 8))
  end

  it "saturates cumulative work rather than wrapping on overflow" do
    saturated = Harpy::Block.new(0, "2026-01-01", Harpy::Block.genesis(difficulty: 16).transactions, "", 16, "0")
    chain = Harpy::Chain.new([saturated, saturated])

    chain.cumulative_work.should eq(UInt64::MAX)
  end
end

describe Harpy::Storage do
  it "round-trips a valid chain to disk" do
    path = File.tempname
    original = Harpy::SpecHelpers.build_chain(2)

    begin
      Harpy::Storage.save(original, path)
      loaded = Harpy::Storage.load(path)

      loaded.should_not be_nil
      loaded.not_nil!.valid?.should be_true
      loaded.not_nil!.blocks.to_json.should eq(original.blocks.to_json)
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "refuses to boot from an invalid stored chain" do
    path = File.tempname
    invalid = Harpy::Chain.new([Harpy::Block.new(0, "2026-01-01", Harpy::Block.genesis(difficulty: 0).transactions, "", 0, "0", "invalid")])

    begin
      Harpy::Storage.save(invalid, path)
      expect_raises Harpy::StorageError do
        Harpy::Storage.load_or_genesis(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "does not leave a temp file behind after a successful save" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(2)

    begin
      Harpy::Storage.save(chain, path)
      File.exists?("#{path}.tmp").should be_false
    ensure
      File.delete?(path) if File.exists?(path)
      File.delete?("#{path}.tmp") if File.exists?("#{path}.tmp")
    end
  end

  it "persists a checksum envelope on disk" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(2)

    begin
      Harpy::Storage.save(chain, path)
      parsed = JSON.parse(File.read(path))
      parsed["checksum"].as_s.size.should eq(64)
      parsed["blocks"].as_a.size.should eq(2)
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "rejects a file whose checksum field was tampered" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(2)

    begin
      forged = Harpy::Storage::Envelope.new("0" * 64, chain.blocks)
      File.write(path, forged.to_json)

      expect_raises Harpy::StorageError do
        Harpy::Storage.load(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "loads a legacy bare-array chain file without a checksum envelope" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(2)

    begin
      File.write(path, chain.blocks.to_json)

      loaded = Harpy::Storage.load(path)
      loaded.should_not be_nil
      loaded.not_nil!.blocks.to_json.should eq(chain.blocks.to_json)
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end
end

describe Harpy::Difficulty do
  it "increases difficulty when blocks arrive faster than the target interval" do
    blocks = [] of Harpy::Block
    txs = Harpy::Block.genesis(difficulty: 0).transactions
    10.times do |i|
      blocks << Harpy::Block.new(
        i,
        Time.utc(2026, 1, 1, 0, 0, i).to_s,
        txs,
        "",
        2,
      )
    end

    Harpy::Difficulty.retarget(blocks).should be > 2
  end

  it "decreases difficulty when blocks arrive slower than the target interval" do
    blocks = [] of Harpy::Block
    txs = Harpy::Block.genesis(difficulty: 0).transactions
    10.times do |i|
      blocks << Harpy::Block.new(
        i,
        Time.utc(2026, 1, 1, 0, i * 6, 0).to_s,
        txs,
        "",
        3,
      )
    end

    Harpy::Difficulty.retarget(blocks).should be < 3
  end
end
