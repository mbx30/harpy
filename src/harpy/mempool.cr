module Harpy
  class Mempool
    getter transactions : Array(Transaction)

    def initialize(@transactions = [] of Transaction)
    end

    def empty? : Bool
      @transactions.empty?
    end

    def size : Int32
      @transactions.size
    end

    def spent_outpoints : Set(OutPoint)
      set = Set(OutPoint).new
      @transactions.each do |tx|
        tx.inputs.each { |input| set.add(input.prev_out) }
      end
      set
    end

    def add(tx : Transaction, utxo_set : UtxoSet, current_height : UInt32) : Mempool::AddResult
      return AddResult::Conflict if conflicts?(tx)
      return AddResult::Invalid unless State.validate_tx(tx, utxo_set, current_height, spent_outpoints)

      @transactions << tx
      AddResult::Accepted
    end

    def conflicts?(tx : Transaction) : Bool
      spent = spent_outpoints
      tx.inputs.any? { |input| spent.includes?(input.prev_out) }
    end

    # Select mempool txs in FIFO order, respecting MAX_TXS_PER_BLOCK and the
    # serialized transactions byte cap. Oversized leading txs are skipped so
    # mining can still produce a valid coinbase-only block.
    def select_for_block(
      previous : Block,
      miner_pubkey : String,
      utxo_set : UtxoSet,
      difficulty : Int32,
      max_count : UInt32 = Economics::MAX_TXS_PER_BLOCK,
    ) : Array(Transaction)
      selected = [] of Transaction

      @transactions.each do |tx|
        break if selected.size >= max_count.to_i32

        trial = selected + [tx]
        candidate = Miner.build_block_with_fees(
          previous,
          trial,
          miner_pubkey,
          difficulty,
          utxo_set,
        )

        if candidate.transactions_within_limit?
          selected = trial
        elsif selected.empty?
          next
        else
          break
        end
      end

      selected
    end

    def remove_txids(txids : Array(String)) : Nil
      id_set = txids.to_set
      @transactions.reject! { |tx| id_set.includes?(tx.txid) }
    end

    enum AddResult
      Accepted
      Invalid
      Conflict
    end
  end
end
