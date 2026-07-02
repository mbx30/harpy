require "spec"
require "../src/harpy/*"

module Harpy::SpecHelpers
  def self.mined_genesis(difficulty : Int32 = 0) : Harpy::Block
    Harpy::Miner.mine(Harpy::Block.genesis(difficulty: difficulty))
  end

  def self.build_chain(block_count : Int32, difficulty : Int32 = 0) : Harpy::Chain
    chain = Harpy::Chain.new([mined_genesis(difficulty)])

    (1...block_count).each do |index|
      chain.append!(Harpy::Miner.mine_next(chain.tip, "block #{index}", verbose: false)).should be_true
    end

    chain
  end
end
