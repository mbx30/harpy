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
          block.data,
          block.prev_hash,
          block.difficulty,
          nonce,
          hash,
        )
      end
    end

    def mine_next(previous : Block, data : String, verbose : Bool = false) : Block
      unmined = Block.new(
        previous.index + 1,
        Time.utc.to_s,
        data,
        previous.hash,
        previous.difficulty,
      )

      mine(unmined, verbose: verbose)
    end

    private def hash_for(block : Block, nonce : String) : String
      Block.new(
        block.index,
        block.timestamp,
        block.data,
        block.prev_hash,
        block.difficulty,
        nonce,
      ).computed_hash
    end
  end
end
