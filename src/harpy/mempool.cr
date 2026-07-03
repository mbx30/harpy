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

    def select_for_block(max_count : UInt32 = Economics::MAX_TXS_PER_BLOCK) : Array(Transaction)
      @transactions.first(max_count.to_i)
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
