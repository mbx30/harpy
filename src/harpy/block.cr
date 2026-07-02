require "openssl/digest"

module Harpy::Block
  extend self

  DEFAULT_DIFFICULTY = 3

  def difficulty
    DEFAULT_DIFFICULTY
  end

  def create(index, timestamp, data, prev_hash)
    block = {
      index:        index,
      timestamp:    timestamp,
      data:         data,
      prev_hash:    prev_hash,
      difficulty:   self.difficulty,
      nonce:        "",
    }

    block.merge({hash: calculate_hash(block)})
  end

  def calculate_hash(block)
    plain_text = "
      #{block[:index]}
      #{block[:timestamp]}
      #{block[:data]}
      #{block[:prev_hash]}
      #{block[:nonce]}
    "

    digest = OpenSSL::Digest.new("SHA256")
    digest.update(plain_text)
    digest.to_s
  end

  def hash_valid?(hash, difficulty)
    hash.starts_with?("0" * difficulty)
  end

  def generate(last_block : Harpy::BlockType, data : String) : Harpy::BlockType
    new_block = create(
      last_block[:index] + 1,
      Time.utc.to_s,
      data,
      last_block[:hash],
    )

    i = 0
    loop do
      nonce = i.to_s(16)
      candidate = new_block.merge({nonce: nonce})

      unless hash_valid?(calculate_hash(candidate), candidate[:difficulty])
        puts "Mining: trying another nonce... #{calculate_hash(candidate)}"
        i += 1
        next
      end

      puts "\nMining complete! Nonce for this block is #{nonce}."
      return candidate.merge({hash: calculate_hash(candidate)})
    end
  end

  def valid?(new_block : Harpy::BlockType, previous_block : Harpy::BlockType) : Bool
    return false if previous_block[:index] + 1 != new_block[:index]
    return false if previous_block[:hash] != new_block[:prev_hash]
    return false if calculate_hash(new_block) != new_block[:hash]

    true
  end
end
