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
        ancestors = @blocks[0...index]
        expected = Harpy::Difficulty.required_for_block(ancestors)
        return false unless block.valid_against?(@blocks[index - 1], working, expected)
        Harpy::State.apply_block(block, working)
      end
    end

    true
  end

  def append!(block : Harpy::Block) : Bool
    return false if @blocks.empty?

    expected = next_difficulty
    return false unless block.valid_against?(tip, @utxo_set, expected)

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

    reorg_to!(candidate)
  end

  def find_block_index_by_hash(hash : String) : Int32?
    @blocks.index { |block| block.hash == hash }
  end

  def has_block?(hash : String) : Bool
    !!find_block_index_by_hash(hash)
  end

  def genesis_hash : String
    @blocks.first.hash
  end

  def block_by_hash(hash : String) : Harpy::Block?
    index = find_block_index_by_hash(hash)
    index.nil? ? nil : @blocks[index]
  end

  # Undo the tip block using the per-block undo log (Phase 5 reorg support).
  def undo_block! : Bool
    return false if @blocks.size <= 1

    undo = @undo_log.pop
    @blocks.pop

    undo.created.each { |outpoint| @utxo_set.remove!(outpoint) }
    undo.spent.each { |spent| @utxo_set.insert!(spent.outpoint, spent.entry) }

    true
  end

  def find_fork_height(candidate : Array(Harpy::Block)) : Int32
    limit = Math.min(@blocks.size, candidate.size) - 1
    limit.downto(0) do |height|
      return height if @blocks[height].hash == candidate[height].hash
    end
    -1
  end

  # Reorganize to a heavier valid fork using undo data instead of full replay.
  def reorg_to!(candidate : Array(Harpy::Block)) : Bool
    replacement = Harpy::Chain.new(candidate)
    return false unless replacement.valid?
    return false unless replacement.cumulative_work > cumulative_work

    fork_height = find_fork_height(candidate)
    return false if fork_height < 0

    while @blocks.size > fork_height + 1
      undo_block!
    end

    (fork_height + 1...candidate.size).each do |index|
      return false unless append!(candidate[index])
    end

    @mempool = Harpy::Mempool.new
    true
  end

  enum BlockAcceptResult
    AlreadyHave
    Connected
    Reorganized
    Orphaned
    Rejected
  end

  def block_structure_valid?(block : Harpy::Block) : Bool
    block.hash_matches? && block.pow_valid? && block.transactions_within_limit?
  end

  # Attempt to connect a block to the chain or store it as an orphan.
  def accept_block!(block : Harpy::Block, orphan_pool : Harpy::P2p::OrphanPool) : BlockAcceptResult
    return BlockAcceptResult::AlreadyHave if has_block?(block.hash)
    return BlockAcceptResult::Rejected unless block_structure_valid?(block)

    if block.prev_hash == tip.hash
      return BlockAcceptResult::Rejected unless append!(block)
      process_orphan_children!(block.hash, orphan_pool)
      return BlockAcceptResult::Connected
    end

    if parent_index = find_block_index_by_hash(block.prev_hash)
      candidate = @blocks[0..parent_index] + [block]
      candidate = extend_candidate_with_orphans(candidate, orphan_pool)

      if heavier_valid_fork?(candidate)
        reorg_to!(candidate)
        prune_orphans_in_chain!(orphan_pool)
        process_orphan_children!(tip.hash, orphan_pool)
        return BlockAcceptResult::Reorganized
      end

      orphan_pool.add(block)
      return BlockAcceptResult::Orphaned
    end

    orphan_pool.add(block)
    process_orphan_children!(tip.hash, orphan_pool)
    BlockAcceptResult::Orphaned
  end

  private def heavier_valid_fork?(candidate : Array(Harpy::Block)) : Bool
    trial = Harpy::Chain.new(candidate)
    trial.valid? && trial.cumulative_work > cumulative_work
  end

  private def extend_candidate_with_orphans(
    candidate : Array(Harpy::Block),
    orphan_pool : Harpy::P2p::OrphanPool,
  ) : Array(Harpy::Block)
    extended = candidate.dup
    loop do
      tip_hash = extended.last.hash
      child = orphan_pool.children_of(tip_hash).find do |block|
        trial = Harpy::Chain.new(extended + [block])
        trial.valid?
      end
      break unless child

      extended << child
    end
    extended
  end

  private def process_orphan_children!(parent_hash : String, orphan_pool : Harpy::P2p::OrphanPool) : Nil
    loop do
      child = orphan_pool.children_of(parent_hash).find do |candidate|
        next false unless candidate.prev_hash == tip.hash

        append!(candidate)
      end
      break unless child

      orphan_pool.remove(child.hash)
      parent_hash = child.hash
    end
  end

  private def prune_orphans_in_chain!(orphan_pool : Harpy::P2p::OrphanPool) : Nil
    @blocks.each { |block| orphan_pool.remove(block.hash) }
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
