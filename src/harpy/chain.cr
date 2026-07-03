class Harpy::Chain
  getter blocks : Array(Harpy::Block)
  getter utxo_set : Harpy::UtxoSet
  getter undo_log : Array(Harpy::UndoEntry)
  getter mempool : Harpy::Mempool

  def initialize(
    @blocks = [] of Harpy::Block,
    @utxo_set = Harpy::UtxoSet.new,
    @undo_log = [] of Harpy::UndoEntry,
    @mempool = Harpy::Mempool.new,
  )
    rebuild_state! unless @blocks.empty?
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

  def rebuild_state! : Nil
    @utxo_set = Harpy::UtxoSet.new
    @undo_log = [] of Harpy::UndoEntry

    @blocks.each do |block|
      undo = Harpy::State.apply_block(block, @utxo_set)
      @undo_log << undo
    end
  end

  def valid? : Bool
    return true if @blocks.empty?

    genesis = @blocks.first
    return false unless genesis.index == 0
    return false unless genesis.prev_hash.empty?
    return false unless genesis.hash_matches?
    return false unless genesis.pow_valid?
    return false unless genesis.transactions_within_limit?

    working = Harpy::UtxoSet.new
    @blocks.each_with_index do |block, index|
      if index == 0
        return false unless block.transactions.first?.try &.is_a?(Harpy::CoinbaseTx)
        return false unless Harpy::State.validate_block_transactions(block, working)
        Harpy::State.apply_block(block, working)
      else
        return false unless block.valid_against?(@blocks[index - 1], working)
        Harpy::State.apply_block(block, working)
      end
    end

    true
  end

  def append!(block : Harpy::Block) : Bool
    return false if @blocks.empty?
    return false unless block.valid_against?(tip, @utxo_set)

    undo = Harpy::State.apply_block(block, @utxo_set)
    @undo_log << undo
    @blocks << block
    true
  end

  def cumulative_work : UInt64
    @blocks.reduce(0_u64) do |acc, block|
      w = block.work
      acc > UInt64::MAX - w ? UInt64::MAX : acc + w
    end
  end

  def replace_if_more_work_valid!(candidate : Array(Harpy::Block)) : Bool
    replacement = Harpy::Chain.new(candidate)
    return false unless replacement.valid?
    return false unless replacement.cumulative_work > cumulative_work

    @blocks = candidate
    @utxo_set = replacement.utxo_set
    @undo_log = replacement.undo_log
    @mempool = Harpy::Mempool.new
    true
  end

  def replace_if_longer_valid!(candidate : Array(Harpy::Block)) : Bool
    replace_if_more_work_valid!(candidate)
  end

  def next_difficulty : Int32
    Harpy::Difficulty.retarget(@blocks)
  end

  def self.genesis_chain(
    miner_pubkey : String = Harpy::Economics.genesis_pubkey,
    difficulty : Int32 = Harpy::Block::DEFAULT_DIFFICULTY,
    verbose : Bool = false,
  ) : Harpy::Chain
    genesis = Harpy::Miner.mine(Harpy::Block.genesis(miner_pubkey: miner_pubkey, difficulty: difficulty), verbose: verbose)
    new([genesis])
  end
end
