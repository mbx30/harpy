module Harpy::Chain
  @@blocks = [] of Harpy::BlockType

  def self.blocks : Array(Harpy::BlockType)
    @@blocks
  end

  def self.genesis
    @@blocks << Harpy::Block.create(0, Time.utc.to_s, "Genesis block's data!", "")
  end

  def self.tip : Harpy::BlockType
    @@blocks.last
  end

  def self.add(block : Harpy::BlockType)
    @@blocks << block
  end
end
