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

  it "rejects attacker-sized positive difficulty before building a PoW prefix" do
    transactions = Harpy::Block.genesis(difficulty: 0).transactions
    draft = Harpy::Block.new(0, "2026-01-01 00:00:00 UTC", transactions, "", Int32::MAX, "0")
    block = Harpy::Block.new(
      draft.index,
      draft.timestamp,
      draft.transactions,
      draft.prev_hash,
      draft.difficulty,
      draft.nonce,
      draft.computed_hash,
      draft.merkle_root,
    )

    block.hash_matches?.should be_true
    block.pow_valid?.should be_false
    block.header.pow_valid?.should be_false
    Harpy::Chain.new([block]).block_structure_valid?(block).should be_false
    expect_raises(ArgumentError) { Harpy::Miner.mine(block) }
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

  it "rejects a child block with the same timestamp as its parent" do
    genesis = Harpy::SpecHelpers.mined_genesis
    coinbase = Harpy::CoinbaseTx.new(
      outputs: [Harpy::TxOutput.new(Harpy::Economics::BLOCK_REWARD, Harpy::Economics.genesis_pubkey)],
      height: 1_u32,
    )
    same_time = Harpy::Miner.mine(
      Harpy::Block.new(1, genesis.timestamp, [coinbase] of Harpy::BlockTx, genesis.hash, genesis.difficulty),
    )

    chain = Harpy::Chain.new([genesis])
    chain.append!(same_time).should be_false
  end

  it "rejects a child block with a timestamp before its parent" do
    genesis = Harpy::SpecHelpers.mined_genesis
    coinbase = Harpy::CoinbaseTx.new(
      outputs: [Harpy::TxOutput.new(Harpy::Economics::BLOCK_REWARD, Harpy::Economics.genesis_pubkey)],
      height: 1_u32,
    )
    backdated = Harpy::Miner.mine(
      Harpy::Block.new(1, "2020-01-01 00:00:00 UTC", [coinbase] of Harpy::BlockTx, genesis.hash, genesis.difficulty),
    )

    chain = Harpy::Chain.new([genesis])
    chain.append!(backdated).should be_false
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
    longer = Harpy::SpecHelpers.extend_fork_from(chain.blocks.first, 3, "longer")

    chain.replace_if_more_work_valid!(longer.blocks).should be_true
    chain.height.should eq(3)

    shorter = Harpy::SpecHelpers.extend_fork_from(chain.blocks.first, 2, "shorter")
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
      parsed["format_version"].as_i.should eq(Harpy::Storage::FORMAT_VERSION)
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
      forged = Harpy::Storage::Envelope.new(Harpy::Storage::FORMAT_VERSION, "0" * 64, chain.blocks)
      File.write(path, forged.to_json)

      expect_raises Harpy::StorageError do
        Harpy::Storage.load(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "rejects a legacy bare-array chain file with the v3 reset message" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(2)

    begin
      File.write(path, chain.blocks.to_json)

      error = expect_raises Harpy::StorageError do
        Harpy::Storage.load(path)
      end
      error.message.not_nil!.should contain("reset chain data")
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "rejects a v2 checksum envelope with the v3 reset message" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(2)

    begin
      legacy = {
        "format_version" => 2,
        "checksum"       => Digest::SHA256.hexdigest(chain.blocks.to_json),
        "blocks"         => JSON.parse(chain.blocks.to_json),
      }
      File.write(path, legacy.to_json)

      error = expect_raises Harpy::StorageError do
        Harpy::Storage.load(path)
      end
      error.message.not_nil!.should contain("harpy-block-v3")
      error.message.not_nil!.should contain("reset chain data")
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "rejects a stored genesis with attacker-sized difficulty without allocating its prefix" do
    path = File.tempname
    draft = Harpy::Block.genesis(timestamp: "2026-01-01 00:00:00 UTC", difficulty: Int32::MAX)
    hostile = Harpy::Block.new(
      draft.index,
      draft.timestamp,
      draft.transactions,
      draft.prev_hash,
      draft.difficulty,
      draft.nonce,
      draft.computed_hash,
      draft.merkle_root,
      draft.anchor_root,
    )

    begin
      File.write(path, Harpy::Storage::Envelope.wrap([hostile]).to_json)
      expect_raises(Harpy::StorageError) { Harpy::Storage.load_or_genesis(path) }
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

    Harpy::Difficulty.retarget(blocks).should eq(3)
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

    Harpy::Difficulty.retarget(blocks).should eq(2)
  end

  it "uses the nine intervals represented by ten blocks and changes by at most one" do
    txs = Harpy::Block.genesis(difficulty: 0).transactions
    base = Time.utc(2026, 1, 1)
    build_window = ->(span_seconds : Int32, difficulty : Int32) do
      (0...10).map do |index|
        offset = (span_seconds * index) // 9
        Harpy::Block.new(
          index,
          (base + offset.seconds).to_s(Harpy::Difficulty::TIMESTAMP_FORMAT),
          txs,
          "",
          difficulty,
        )
      end
    end

    Harpy::Difficulty.retarget(build_window.call(269, 3)).should eq(4)
    Harpy::Difficulty.retarget(build_window.call(270, 3)).should eq(3)
    Harpy::Difficulty.retarget(build_window.call(1080, 3)).should eq(3)
    Harpy::Difficulty.retarget(build_window.call(1081, 3)).should eq(2)
    Harpy::Difficulty.retarget(build_window.call(1, 8)).should eq(8)
    Harpy::Difficulty.retarget(build_window.call(5000, 0)).should eq(0)
  end

  it "requires timestamps strictly above the median of the previous eleven blocks" do
    txs = Harpy::Block.genesis(difficulty: 0).transactions
    base = Time.utc(2026, 1, 1)
    ancestors = (1..11).map do |seconds|
      Harpy::Block.new(
        seconds - 1,
        (base + seconds.seconds).to_s(Harpy::Difficulty::TIMESTAMP_FORMAT),
        txs,
        "",
        0,
      )
    end
    now = base + 1.day

    Harpy::Difficulty.valid_timestamp?(
      (base + 6.seconds).to_s(Harpy::Difficulty::TIMESTAMP_FORMAT),
      ancestors,
      now,
    ).should be_false
    Harpy::Difficulty.valid_timestamp?(
      (base + 7.seconds).to_s(Harpy::Difficulty::TIMESTAMP_FORMAT),
      ancestors,
      now,
    ).should be_true
  end

  it "accepts exactly two hours of future drift and rejects anything later" do
    txs = Harpy::Block.genesis(difficulty: 0).transactions
    now = Time.utc(2026, 1, 1, 12, 0, 0)
    ancestor_time = now - 1.minute
    ancestors = [Harpy::Block.new(0, ancestor_time.to_s(Harpy::Difficulty::TIMESTAMP_FORMAT), txs, "", 0)]

    Harpy::Difficulty.valid_timestamp?(
      (now + 2.hours).to_s(Harpy::Difficulty::TIMESTAMP_FORMAT),
      ancestors,
      now,
    ).should be_true
    Harpy::Difficulty.valid_timestamp?(
      (now + 2.hours + 1.second).to_s(Harpy::Difficulty::TIMESTAMP_FORMAT),
      ancestors,
      now,
    ).should be_false
  end
end
