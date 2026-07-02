require "spec"
require "../src/harpy/*"
require "../src/harpy/block"

describe Harpy::Block do
  it "has a version" do
    Harpy::VERSION.should_not be_nil
  end

  it "creates a block with a hash" do
    block = Harpy::Block.create(0, "2026-01-01", "test", "")
    block[:hash].size.should eq(64)
    block[:difficulty].should eq(Harpy::Block::DEFAULT_DIFFICULTY)
  end

  it "validates hash difficulty" do
    Harpy::Block.hash_valid?("000abc", 3).should be_true
    Harpy::Block.hash_valid?("00abc", 3).should be_false
  end

  it "validates block linkage" do
    genesis = Harpy::Block.create(0, "2026-01-01", "genesis", "")
    mined = Harpy::Block.generate(genesis, "block two")

    Harpy::Block.valid?(mined, genesis).should be_true
  end
end
