module Harpy
  module State
    extend self

    def validate_tx(
      tx : Transaction,
      utxo_set : UtxoSet,
      current_height : UInt32,
      mempool_spent : Set(OutPoint) = Set(OutPoint).new,
    ) : Bool
      return false unless tx.version == Economics::TX_VERSION
      return false if tx.inputs.empty? || tx.outputs.empty?
      return false if tx.duplicate_inputs?

      input_sum = 0_u64
      tx.inputs.each do |input|
        entry = utxo_set[input.prev_out]
        return false unless entry
        return false unless utxo_set.spendable?(input.prev_out, current_height)
        return false if mempool_spent.includes?(input.prev_out)
        input_sum += entry.output.amount
      end

      output_sum = tx.outputs.sum(0_u64, &.amount)
      return false if output_sum > input_sum

      fee = input_sum - output_sum
      return false if fee < Economics::MIN_TX_FEE
      return false unless tx.signatures_valid?(utxo_set)

      true
    end

    def validate_coinbase(
      coinbase : CoinbaseTx,
      block_height : UInt32,
      fees_in_block : UInt64,
      miner_pubkey : String,
    ) : Bool
      return false unless coinbase.version == Economics::TX_VERSION
      return false unless coinbase.outputs.size == 1
      return false unless coinbase.height == block_height
      return false unless coinbase.outputs.first.pubkey == miner_pubkey
      return false unless coinbase.outputs.first.amount == Economics::BLOCK_REWARD + fees_in_block

      true
    end

    def apply_tx(tx : Transaction, utxo_set : UtxoSet, block_height : UInt32) : UndoEntry
      undo = UndoEntry.new(block_height)

      tx.inputs.each do |input|
        if entry = utxo_set.remove!(input.prev_out)
          undo.spent << UndoSpent.new(input.prev_out, entry)
        end
      end

      tx.outputs.each_with_index do |output, index|
        outpoint = OutPoint.new(tx.txid, index.to_u32)
        entry = UtxoEntry.new(output, block_height, is_coinbase: false)
        utxo_set.insert!(outpoint, entry)
        undo.created << outpoint
      end

      undo
    end

    def apply_coinbase(coinbase : CoinbaseTx, utxo_set : UtxoSet, block_height : UInt32) : UndoEntry
      undo = UndoEntry.new(block_height)
      output = coinbase.outputs.first

      outpoint = OutPoint.new(coinbase.txid, 0_u32)
      entry = UtxoEntry.new(output, block_height, is_coinbase: true)
      utxo_set.insert!(outpoint, entry)
      undo.created << outpoint

      undo
    end

    def user_transactions(block : Block) : Array(Transaction)
      return [] of Transaction if block.transactions.size <= 1

      block.transactions[1..].map(&.as(Transaction))
    end

    def fees_in_block(block : Block, utxo_before : UtxoSet) : UInt64
      user_transactions(block).sum(0_u64) do |tx|
        tx.fee(utxo_before)
      end
    end

    def miner_pubkey(block : Block) : String?
      coinbase = block.transactions.first?
      return nil unless coinbase.is_a?(CoinbaseTx)
      return nil if coinbase.outputs.empty?

      coinbase.outputs.first.pubkey
    end

    def validate_block_transactions(block : Block, utxo_set : UtxoSet) : Bool
      return false if block.transactions.empty?

      first = block.transactions.first
      return false unless first.is_a?(CoinbaseTx)

      working = utxo_set.dup_set
      user_txs = user_transactions(block)
      fees = 0_u64

      user_txs.each do |tx|
        return false unless validate_tx(tx, working, block.index.to_u32)
        fees += tx.fee(working)
        apply_tx(tx, working, block.index.to_u32)
      end

      miner = first.outputs.first.pubkey
      return false unless validate_coinbase(first, block.index.to_u32, fees, miner)
      return false unless block.merkle_root == Merkle.root(block.transactions.map(&.txid))

      true
    end

    def apply_block(block : Block, utxo_set : UtxoSet) : UndoEntry
      first = block.transactions.first.as(CoinbaseTx)
      undo = apply_coinbase(first, utxo_set, block.index.to_u32)

      user_transactions(block).each do |tx|
        fragment = apply_tx(tx, utxo_set, block.index.to_u32)
        undo.spent.concat(fragment.spent)
        undo.created.concat(fragment.created)
      end

      undo
    end
  end
end
