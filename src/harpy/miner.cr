module Harpy
  module Miner
    extend self

    def mine(block : Block, verbose : Bool = false) : Block
      unless Difficulty.valid_difficulty?(block.difficulty)
        raise ArgumentError.new("difficulty must be between #{Economics::MIN_DIFFICULTY} and #{Economics::MAX_DIFFICULTY}")
      end

      target = "0" * block.difficulty
      i = 0
      loop do
        # Let other fibers (HTTP, P2P, job polling) run while an async mining
        # job grinds through nonces (MIC-44).
        Fiber.yield if i & 0xFFF == 0
        nonce = i.to_s(16)
        hash = hash_for(block, nonce)

        unless hash.starts_with?(target)
          puts "Mining: trying another nonce... #{hash}" if verbose
          i += 1
          next
        end

        puts "\nMining complete! Nonce for this block is #{nonce}.\n" if verbose
        return Block.new(
          block.index,
          block.timestamp,
          block.transactions,
          block.prev_hash,
          block.difficulty,
          nonce,
          hash,
          block.merkle_root,
          block.anchor_root,
        )
      end
    end

    def build_block_with_fees(
      previous : Block,
      user_txs : Array(Transaction),
      miner_pubkey : String,
      difficulty : Int32,
      utxo_set : UtxoSet,
      anchor_root : String = "",
    ) : Block
      fees = 0_u64
      user_txs.each do |tx|
        next_fees = State.checked_add(fees, tx.fee(utxo_set))
        raise ArgumentError.new("transaction fees exceed UInt64 capacity") unless next_fees
        fees = next_fees
      end
      reward = State.checked_add(Economics::BLOCK_REWARD, fees)
      raise ArgumentError.new("block reward plus fees exceed UInt64 capacity") unless reward
      coinbase = CoinbaseTx.new(
        outputs: [TxOutput.new(reward, miner_pubkey)],
        height: (previous.index + 1).to_u32,
      )

      txs = [coinbase] + user_txs
      Block.new(
        previous.index + 1,
        Difficulty.next_timestamp([previous]),
        txs,
        previous.hash,
        difficulty,
        anchor_root: anchor_root,
      )
    end

    def mine_from_mempool(
      chain : Chain,
      miner_pubkey : String,
      verbose : Bool = false,
      anchor_root : String = "",
    ) : Block
      difficulty = chain.next_difficulty
      selected = chain.mempool.select_for_block(
        chain.tip,
        miner_pubkey,
        chain.utxo_set,
        difficulty,
      )
      unmined = build_block_with_fees(chain.tip, selected, miner_pubkey, difficulty, chain.utxo_set, anchor_root)
      unmined = Block.new(
        unmined.index,
        Difficulty.next_timestamp(chain.blocks),
        unmined.transactions,
        unmined.prev_hash,
        unmined.difficulty,
        unmined.nonce,
        unmined.hash,
        unmined.merkle_root,
        unmined.anchor_root,
      )
      mine(unmined, verbose: verbose)
    end

    private def hash_for(block : Block, nonce : String) : String
      Block.new(
        block.index,
        block.timestamp,
        block.transactions,
        block.prev_hash,
        block.difficulty,
        nonce,
        "",
        block.merkle_root,
        block.anchor_root,
      ).computed_hash
    end
  end
end
