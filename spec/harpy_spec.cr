require "./spec_helper"

describe Harpy::Block do
  it "has a version" do
    Harpy::VERSION.should eq("0.1.0")
  end

  it "computes a deterministic hash" do
    block = Harpy::Block.new(0, "2026-01-01", "test", "", 0, "0")
    hash = block.computed_hash

    hash.size.should eq(64)
    Harpy::Block.new(0, "2026-01-01", "test", "", 0, "0").computed_hash.should eq(hash)
  end

  it "validates proof-of-work difficulty" do
    Harpy::Block.new(0, "2026-01-01", "test", "", 3, "0", "000abc").pow_valid?.should be_true
    Harpy::Block.new(0, "2026-01-01", "test", "", 3, "0", "00abc").pow_valid?.should be_false
  end

  it "treats a negative difficulty as invalid PoW instead of raising" do
    Harpy::Block.new(0, "2026-01-01", "test", "", -1, "0", "abc").pow_valid?.should be_false
  end

  it "commits to fields injectively so a crafted data string cannot spoof another block" do
    # A `data` payload that embeds what a naive newline-joined preimage would
    # read as the timestamp/prev_hash/nonce of a different block must NOT hash to
    # that other block. Length-prefixing makes the field boundaries unforgeable.
    injected = Harpy::Block.new(0, "ts", "d\nprev\nnonce", "", 0, "x")
    spoofed = Harpy::Block.new(0, "ts", "d", "prev", 0, "nonce\nx")

    injected.computed_hash.should_not eq(spoofed.computed_hash)
  end

  it "saturates work instead of overflowing to zero at high difficulty" do
    # 4 * 16 = 64-bit shift would wrap a raw `1 << shift` to 0.
    Harpy::Block.new(0, "2026-01-01", "test", "", 16, "0").work.should eq(UInt64::MAX)
    Harpy::Block.new(0, "2026-01-01", "test", "", 15, "0").work.should eq(1_u64 << 60)
    Harpy::Block.new(0, "2026-01-01", "test", "", 0, "0").work.should eq(1_u64)
  end

  it "validates linkage and hash integrity against the previous block" do
    genesis = Harpy::SpecHelpers.mined_genesis
    next_block = Harpy::Miner.mine_next(genesis, "block two")

    next_block.valid_against?(genesis).should be_true
  end

  it "rejects blocks with a tampered hash" do
    genesis = Harpy::SpecHelpers.mined_genesis
    next_block = Harpy::Miner.mine_next(genesis, "block two")
    tampered = Harpy::Block.new(
      next_block.index,
      next_block.timestamp,
      next_block.data,
      next_block.prev_hash,
      next_block.difficulty,
      next_block.nonce,
      "deadbeef",
    )

    tampered.valid_against?(genesis).should be_false
  end

  it "accepts a child block with the same timestamp as its parent" do
    genesis = Harpy::SpecHelpers.mined_genesis
    same_time = Harpy::Miner.mine(
      Harpy::Block.new(1, genesis.timestamp, "same time", genesis.hash, genesis.difficulty),
    )

    same_time.valid_against?(genesis).should be_true
  end

  it "rejects a child block with a timestamp before its parent" do
    genesis = Harpy::SpecHelpers.mined_genesis
    backdated = Harpy::Miner.mine(
      Harpy::Block.new(1, "2020-01-01 00:00:00 UTC", "backdated", genesis.hash, genesis.difficulty),
    )

    backdated.valid_against?(genesis).should be_false
  end

  it "accepts a block with data at the configured size cap" do
    genesis = Harpy::SpecHelpers.mined_genesis
    next_block = Harpy::Miner.mine_next(genesis, "y" * Harpy::Config.max_block_data_bytes)

    next_block.data_within_limit?.should be_true
    next_block.valid_against?(genesis).should be_true
  end

  it "rejects a block with data exceeding the configured size cap, even if mined and hash-valid" do
    genesis = Harpy::SpecHelpers.mined_genesis
    oversized = Harpy::Miner.mine_next(genesis, "y" * (Harpy::Config.max_block_data_bytes + 1))

    oversized.data_within_limit?.should be_false
    oversized.valid_against?(genesis).should be_false
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
    orphan = Harpy::Miner.mine(Harpy::Block.new(99, Time.utc.to_s, "orphan", "missing", 0))

    chain.append!(orphan).should be_false
    chain.height.should eq(2)
  end

  it "rejects appending a block with a regressive timestamp" do
    chain = Harpy::SpecHelpers.build_chain(2)
    tip = chain.tip
    backdated = Harpy::Miner.mine(
      Harpy::Block.new(tip.index + 1, "2020-01-01 00:00:00 UTC", "backdated", tip.hash, tip.difficulty),
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
    saturated = Harpy::Block.new(0, "2026-01-01", "a", "", 16, "0")
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
    invalid = Harpy::Chain.new([Harpy::Block.new(0, "2026-01-01", "bad", "", 0, "0", "invalid")])

    begin
      Harpy::Storage.save(invalid, path)
      expect_raises Harpy::StorageError do
        Harpy::Storage.load_or_genesis(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "refuses to boot from a stored chain with an oversize genesis payload" do
    path = File.tempname
    oversized_genesis = Harpy::Miner.mine(
      Harpy::Block.genesis("y" * (Harpy::Config.max_block_data_bytes + 1), difficulty: 0),
    )
    invalid = Harpy::Chain.new([oversized_genesis])

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

  it "overwrites an existing file atomically on repeated saves" do
    path = File.tempname
    first = Harpy::SpecHelpers.build_chain(2)
    second = Harpy::SpecHelpers.build_chain(3)

    begin
      Harpy::Storage.save(first, path)
      Harpy::Storage.save(second, path)

      loaded = Harpy::Storage.load(path)
      loaded.should_not be_nil
      loaded.not_nil!.height.should eq(3)
      loaded.not_nil!.blocks.to_json.should eq(second.blocks.to_json)
    ensure
      File.delete?(path) if File.exists?(path)
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
      # Correct blocks, deliberately wrong checksum.
      forged = Harpy::Storage::Envelope.new("0" * 64, chain.blocks)
      File.write(path, forged.to_json)

      expect_raises Harpy::StorageError do
        Harpy::Storage.load(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "rejects a file whose block bytes were tampered but checksum left intact" do
    path = File.tempname
    chain = Harpy::SpecHelpers.build_chain(2)

    begin
      Harpy::Storage.save(chain, path)
      # Mutate a block's data in place; the stored checksum no longer matches.
      tampered = File.read(path).sub("block 1", "hacked!")
      File.write(path, tampered)

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
      # Legacy format: a bare JSON array of blocks, no envelope.
      File.write(path, chain.blocks.to_json)

      loaded = Harpy::Storage.load(path)
      loaded.should_not be_nil
      loaded.not_nil!.blocks.to_json.should eq(chain.blocks.to_json)
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "rejects a chain file that is not valid JSON" do
    path = File.tempname

    begin
      File.write(path, "{ this is not json")

      expect_raises Harpy::StorageError do
        Harpy::Storage.load(path)
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end
end

describe Harpy::Storage::FileBackend do
  it "round-trips a chain through the backend interface" do
    path = File.tempname
    backend = Harpy::Storage::FileBackend.new(path)
    chain = Harpy::SpecHelpers.build_chain(2)

    begin
      backend.save(chain)
      loaded = backend.load

      loaded.should_not be_nil
      loaded.not_nil!.valid?.should be_true
      loaded.not_nil!.blocks.to_json.should eq(chain.blocks.to_json)
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end

  it "returns nil when nothing has been persisted yet" do
    path = File.tempname
    Harpy::Storage::FileBackend.new(path).load.should be_nil
  end

  it "rejects a corrupted store through the backend interface" do
    path = File.tempname
    backend = Harpy::Storage::FileBackend.new(path)
    chain = Harpy::SpecHelpers.build_chain(2)

    begin
      backend.save(chain)
      File.write(path, File.read(path).sub("block 1", "hacked!"))

      expect_raises Harpy::StorageError do
        backend.load
      end
    ensure
      File.delete?(path) if File.exists?(path)
    end
  end
end
