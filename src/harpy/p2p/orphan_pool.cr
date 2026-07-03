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
        return false if @blocks.has_key?(block.hash)
        return false if @size >= MAX_SIZE

        @blocks[block.hash] = block
        @children[block.prev_hash] ||= [] of String
        @children[block.prev_hash] << block.hash unless @children[block.prev_hash].includes?(block.hash)
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

        @children.delete(hash)
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
    end
  end
end
