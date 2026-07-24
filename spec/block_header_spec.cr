require "./spec_helper"

describe Harpy::BlockHeader do
  it "derives a header whose hash matches the full block" do
    chain = Harpy::SpecHelpers.build_chain(2)
    block = chain.blocks.last

    header = block.header
    header.hash.should eq(block.hash)
    header.merkle_root.should eq(block.merkle_root)
    header.computed_hash.should eq(block.computed_hash)
    header.hash_matches?.should be_true
  end

  it "verifies proof-of-work from the header alone" do
    block = Harpy::SpecHelpers.mined_genesis(difficulty: 0)
    block.header.pow_valid?.should be_true
  end

  it "round-trips through JSON" do
    block = Harpy::SpecHelpers.mined_genesis(difficulty: 0)
    restored = Harpy::BlockHeader.from_json(block.header.to_json)

    restored.hash.should eq(block.hash)
    restored.hash_matches?.should be_true
  end

  it "detects a tampered header (hash no longer matches preimage)" do
    block = Harpy::SpecHelpers.build_chain(2).blocks.last
    tampered = Harpy::BlockHeader.new(
      block.index,
      block.timestamp,
      "deadbeef" * 8, # wrong merkle_root
      block.prev_hash,
      block.difficulty,
      block.nonce,
      block.hash,
    )

    tampered.hash_matches?.should be_false
  end

  it "detects difficulty and anchor-root tampering" do
    block = Harpy::SpecHelpers.build_chain(2).blocks.last
    changed_difficulty = Harpy::BlockHeader.new(
      block.index,
      block.timestamp,
      block.merkle_root,
      block.prev_hash,
      block.difficulty + 1,
      block.nonce,
      block.hash,
      block.anchor_root,
    )
    changed_anchor = Harpy::BlockHeader.new(
      block.index,
      block.timestamp,
      block.merkle_root,
      block.prev_hash,
      block.difficulty,
      block.nonce,
      block.hash,
      "ab" * 32,
    )

    changed_difficulty.hash_matches?.should be_false
    changed_anchor.hash_matches?.should be_false
  end
end
