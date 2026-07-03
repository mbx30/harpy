module Harpy
  struct UtxoEntry
    getter output : TxOutput
    getter created_height : UInt32
    getter is_coinbase : Bool

    def initialize(@output : TxOutput, @created_height : UInt32, @is_coinbase : Bool = false)
    end
  end

  struct UndoSpent
    include JSON::Serializable

    getter outpoint : OutPoint
    getter entry : UtxoEntry

    def initialize(@outpoint : OutPoint, @entry : UtxoEntry)
    end
  end

  struct UndoEntry
    include JSON::Serializable

    getter height : UInt32
    getter spent : Array(UndoSpent)
    getter created : Array(OutPoint)

    def initialize(
      @height : UInt32,
      @spent : Array(UndoSpent) = [] of UndoSpent,
      @created : Array(OutPoint) = [] of OutPoint,
    )
    end
  end

  class UtxoSet
    @entries = {} of OutPoint => UtxoEntry

    def [](outpoint : OutPoint) : UtxoEntry?
      @entries[outpoint]?
    end

    def empty? : Bool
      @entries.empty?
    end

    def size : Int32
      @entries.size
    end

    def balance(pubkey : String) : UInt64
      @entries.values.sum(0_u64) do |entry|
        entry.output.pubkey == pubkey ? entry.output.amount : 0_u64
      end
    end

    def spendable?(outpoint : OutPoint, current_height : UInt32) : Bool
      entry = @entries[outpoint]?
      return false unless entry
      return true unless entry.is_coinbase

      current_height - entry.created_height >= Economics::COINBASE_MATURITY
    end

    def remove!(outpoint : OutPoint) : UtxoEntry?
      @entries.delete(outpoint)
    end

    def insert!(outpoint : OutPoint, entry : UtxoEntry) : Nil
      @entries[outpoint] = entry
    end

    def dup_set : UtxoSet
      copy = UtxoSet.new
      @entries.each { |k, v| copy.insert!(k, v) }
      copy
    end
  end
end
