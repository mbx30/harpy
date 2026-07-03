require "./spec_helper"

describe "canonical hash serialization" do
  vectors = JSON.parse(File.read(File.expand_path("fixtures/hash_vectors.json", __DIR__)))

  vectors.as_a.each do |vector|
    description = vector["description"].as_s

    it "matches vector: #{description}" do
      block = Harpy::Block.genesis(timestamp: vector["timestamp"].as_s, difficulty: 0)
      block.computed_hash.should eq(vector["expected_hash"].as_s)
      block.merkle_root.should eq(vector["merkle_root"].as_s)
    end
  end

  it "documents that difficulty is excluded from the hash input" do
    txs = Harpy::Block.genesis(difficulty: 0).transactions
    base = Harpy::Block.new(0, "2026-01-01", txs, "", 0, "0")
    harder = Harpy::Block.new(0, "2026-01-01", txs, "", 99, "0")

    base.computed_hash.should eq(harder.computed_hash)
  end
end
