module Harpy
  module Miner
    extend self

    def mine(block : Block, verbose : Bool = false) : Block
      i = 0
      loop do
        nonce = i.to_s(16)
        hash = hash_for(block, nonce)

        unless hash.starts_with?("0" * block.difficulty)
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
        )
      end
    end

    def build_block_with_fees(
      previous : Block,
      user_txs : Array(Transaction),
      miner_pubkey : String,
      difficulty : Int32,
      utxo_set : UtxoSet,
    ) : Block
      fees = user_txs.sum(0_u64) { |tx| tx.fee(utxo_set) }
      coinbase = CoinbaseTx.new(
        outputs: [TxOutput.new(Economics::BLOCK_REWARD + fees, miner_pubkey)],
        height: (previous.index + 1).to_u32,
      )

      txs = [coinbase] + user_txs
      Block.new(
        previous.index + 1,
        Time.utc.to_s,
        txs,
        previous.hash,
        difficulty,
      )
    end

    def mine_from_mempool(
      chain : Chain,
      miner_pubkey : String,
      verbose : Bool = false,
    ) : Block
      difficulty = chain.next_difficulty
      selected = chain.mempool.select_for_block(
        chain.tip,
        miner_pubkey,
        chain.utxo_set,
        difficulty,
      )
      unmined = build_block_with_fees(chain.tip, selected, miner_pubkey, difficulty, chain.utxo_set)
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
      ).computed_hash
    end
  end
end
