module Harpy
  module P2p
    # Buffers blocks whose parent is not yet known (out-of-order arrivals).
    class OrphanPool
      MAX_SIZE = 100

      getter size : Int32

      def initialize
        @blocks = {} of String => Block
        @children = {} of String => Array(String)
        @size = 0
      end

      def has?(hash : String) : Bool
        @blocks.has_key?(hash)
      end

      def get(hash : String) : Block?
        @blocks[hash]?
      end

      def add(block : Block) : Bool
        key = block_key(block)
        return false if @blocks.has_key?(key)
        return false if @size >= MAX_SIZE

        @blocks[key] = block
        @children[block.prev_hash] ||= [] of String
        @children[block.prev_hash] << key unless @children[block.prev_hash].includes?(key)
        @size += 1
        true
      end

      def remove(hash : String) : Block?
        block = @blocks.delete(hash)
        return nil unless block

        if children = @children[block.prev_hash]?
          children.delete(hash)
          @children.delete(block.prev_hash) if children.empty?
        end

        @size -= 1
        block
      end

      def children_of(parent_hash : String) : Array(Block)
        @children[parent_hash]?.try(&.compact_map { |hash| @blocks[hash]? }) || [] of Block
      end

      def clear : Nil
        @blocks.clear
        @children.clear
        @size = 0
      end

      # Unmined blocks may carry an empty `hash`; use the canonical preimage instead.
      private def block_key(block : Block) : String
        block.hash.empty? ? block.computed_hash : block.hash
      end
    end
  end
end
