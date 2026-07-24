require "./spec_helper"

describe "canonical hash serialization" do
  vectors = JSON.parse(File.read(File.expand_path("fixtures/hash_vectors.json", __DIR__)))

  vectors.as_a.each do |vector|
    description = vector["description"].as_s

    it "matches vector: #{description}" do
      genesis = Harpy::Block.genesis(timestamp: vector["timestamp"].as_s, difficulty: 0)
      block = Harpy::Block.new(
        vector["index"].as_i.to_i32,
        vector["timestamp"].as_s,
        genesis.transactions,
        vector["prev_hash"].as_s,
        vector["difficulty"].as_i.to_i32,
        vector["nonce"].as_s,
        anchor_root: vector["anchor_root"].as_s,
      )
      block.computed_hash.should eq(vector["expected_hash"].as_s)
      block.merkle_root.should eq(vector["merkle_root"].as_s)
    end
  end

  it "commits difficulty to the v3 hash input" do
    txs = Harpy::Block.genesis(difficulty: 0).transactions
    base = Harpy::Block.new(0, "2026-01-01", txs, "", 0, "0")
    harder = Harpy::Block.new(0, "2026-01-01", txs, "", 1, "0")

    base.computed_hash.should_not eq(harder.computed_hash)
  end

  it "commits an empty or populated anchor root unconditionally" do
    txs = Harpy::Block.genesis(difficulty: 0).transactions
    empty = Harpy::Block.new(0, "2026-01-01", txs, "", 0, "0", anchor_root: "")
    anchored = Harpy::Block.new(0, "2026-01-01", txs, "", 0, "0", anchor_root: "ab" * 32)

    empty.computed_hash.should_not eq(anchored.computed_hash)
  end
end
