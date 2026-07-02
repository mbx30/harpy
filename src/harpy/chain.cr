class Harpy::Chain
  getter blocks : Array(Harpy::Block)

  def initialize(@blocks = [] of Harpy::Block)
  end

  def height : Int32
    @blocks.size
  end

  def tip : Harpy::Block
    @blocks.last
  end

  def empty? : Bool
    @blocks.empty?
  end

  def valid? : Bool
    return true if @blocks.empty?

    genesis = @blocks.first
    return false unless genesis.index == 0
    return false unless genesis.prev_hash.empty?
    return false unless genesis.hash_matches?
    return false unless genesis.pow_valid?

    @blocks.each_with_index do |block, index|
      next if index == 0
      return false unless block.valid_against?(@blocks[index - 1])
    end

    true
  end

  def append!(block : Harpy::Block) : Bool
    return false if @blocks.empty?
    return false unless block.valid_against?(tip)

    @blocks << block
    true
  end

  def replace_if_longer_valid!(candidate : Array(Harpy::Block)) : Bool
    replacement = Harpy::Chain.new(candidate)
    return false unless replacement.valid?
    return false unless candidate.size > @blocks.size

    @blocks = candidate
    true
  end

  def self.genesis_chain(
    data : String = "Genesis block's data!",
    difficulty : Int32 = Harpy::Block::DEFAULT_DIFFICULTY,
    verbose : Bool = false,
  ) : Harpy::Chain
    genesis = Harpy::Miner.mine(Harpy::Block.genesis(data, difficulty: difficulty), verbose: verbose)
    new([genesis])
  end
end
