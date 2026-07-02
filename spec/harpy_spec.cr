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

  it "replaces the chain only with a longer valid candidate" do
    chain = Harpy::SpecHelpers.build_chain(2)
    longer = Harpy::SpecHelpers.build_chain(3)

    chain.replace_if_longer_valid!(longer.blocks).should be_true
    chain.height.should eq(3)

    shorter = Harpy::SpecHelpers.build_chain(2)
    chain.replace_if_longer_valid!(shorter.blocks).should be_false
    chain.height.should eq(3)
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
end
