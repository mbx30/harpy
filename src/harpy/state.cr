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
      return false unless tx.outputs.all? { |output| Crypto.valid_pubkey_hex?(output.pubkey) }

      input_sum = 0_u64
      tx.inputs.each do |input|
        entry = utxo_set[input.prev_out]
        return false unless entry
        return false unless utxo_set.spendable?(input.prev_out, current_height)
        return false if mempool_spent.includes?(input.prev_out)
        next_input_sum = checked_add(input_sum, entry.output.amount)
        return false unless next_input_sum
        input_sum = next_input_sum
      end

      output_sum = checked_sum_outputs(tx.outputs)
      return false unless output_sum
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
      return false unless Crypto.valid_pubkey_hex?(coinbase.outputs.first.pubkey)
      return false unless coinbase.height == block_height
      return false unless coinbase.outputs.first.pubkey == miner_pubkey
      expected_amount = checked_add(Economics::BLOCK_REWARD, fees_in_block)
      return false unless expected_amount
      return false unless coinbase.outputs.first.amount == expected_amount

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
      return false unless block_transactions_structurally_valid?(block)

      first = block.transactions.first
      return false unless first.is_a?(CoinbaseTx)

      working = utxo_set.dup_set
      user_txs = user_transactions(block)
      fees = 0_u64

      user_txs.each do |tx|
        return false unless validate_tx(tx, working, block.index.to_u32)
        next_fees = checked_add(fees, tx.fee(working))
        return false unless next_fees
        fees = next_fees
        apply_tx(tx, working, block.index.to_u32)
      end

      miner = first.outputs.first.pubkey
      return false unless validate_coinbase(first, block.index.to_u32, fees, miner)
      return false unless block.merkle_root == Merkle.root(block.transactions.map(&.txid))

      true
    end

    # Checks transaction shape without needing the parent UTXO set. This is
    # safe to run before admitting an unknown-parent block to the orphan pool.
    def block_transactions_structurally_valid?(block : Block) : Bool
      return false if block.transactions.empty?

      first = block.transactions.first
      return false unless first.is_a?(CoinbaseTx)
      return false unless first.version == Economics::TX_VERSION
      return false unless first.outputs.size == 1
      return false unless Crypto.valid_pubkey_hex?(first.outputs.first.pubkey)

      block.transactions[1..].each do |entry|
        return false unless entry.is_a?(Transaction)
        return false unless entry.version == Economics::TX_VERSION
        return false if entry.inputs.empty? || entry.outputs.empty?
        return false if entry.duplicate_inputs?
        return false unless entry.outputs.all? { |output| Crypto.valid_pubkey_hex?(output.pubkey) }
        return false unless checked_sum_outputs(entry.outputs)
      end

      block.merkle_root == Merkle.root(block.transactions.map(&.txid))
    end

    def checked_add(left : UInt64, right : UInt64) : UInt64?
      return nil if right > UInt64::MAX - left

      left + right
    end

    def checked_sum_outputs(outputs : Array(TxOutput)) : UInt64?
      total = 0_u64
      outputs.each do |output|
        next_total = checked_add(total, output.amount)
        return nil unless next_total
        total = next_total
      end
      total
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
