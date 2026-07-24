require "./merkle"
require "./block_header"

module Harpy
  # Simplified Payment Verification: confirm a transaction is committed to a block
  # using only the block *header* and a Merkle inclusion proof — no full node, no
  # transaction bodies. This is the client side of the anchoring endgame
  # (hash-on-chain, data off-chain).
  module Spv
    extend self

    # A transaction is included in the selected target header's block iff:
    #   1. the header's own hash matches its canonical preimage (untampered), and
    #   2. the header satisfies its proof-of-work, and
    #   3. the Merkle proof reconstructs the header's `merkle_root` from `txid`.
    def verify_inclusion(
      txid : String,
      proof : Array(Merkle::ProofStep),
      headers : Array(BlockHeader),
      target_index : Int32,
      trusted_genesis_hash : String,
      trusted_tip_hash : String,
      now : Time = Time.utc,
    ) : Bool
      return false unless verify_header_chain(headers, trusted_genesis_hash, trusted_tip_hash, now)
      target = headers.find { |header| header.index == target_index }
      return false unless target

      Merkle.verify_proof(txid, proof, target.merkle_root)
    end

    # An anchored record hash is committed to `header`'s block iff the header is
    # untampered, satisfies PoW, and the proof reconstructs its `anchor_root`.
    # This is the client-side check for the Merkle anchoring API (MIC-81).
    def verify_anchor(
      record_hash : String,
      proof : Array(Merkle::ProofStep),
      headers : Array(BlockHeader),
      target_index : Int32,
      trusted_genesis_hash : String,
      trusted_tip_hash : String,
      now : Time = Time.utc,
    ) : Bool
      return false unless verify_header_chain(headers, trusted_genesis_hash, trusted_tip_hash, now)
      target = headers.find { |header| header.index == target_index }
      return false unless target
      return false if target.anchor_root.empty?

      Merkle.verify_proof(record_hash, proof, target.anchor_root)
    end

    # Verify a contiguous run between caller-pinned genesis and tip hashes.
    # PoW — the header-chain a light client syncs before checking inclusions.
    def verify_header_chain(
      headers : Array(BlockHeader),
      trusted_genesis_hash : String,
      trusted_tip_hash : String,
      now : Time = Time.utc,
    ) : Bool
      return false if headers.empty?

      genesis = headers.first
      return false unless genesis.index == 0
      return false unless genesis.prev_hash.empty?
      return false unless genesis.hash == trusted_genesis_hash
      return false unless headers.last.hash == trusted_tip_hash
      return false unless Difficulty.valid_difficulty?(genesis.difficulty)
      return false unless genesis.hash_matches? && genesis.pow_valid?
      return false unless Difficulty.valid_genesis_timestamp?(genesis.timestamp, now)

      headers.each_with_index do |header, index|
        next if index == 0

        ancestors = headers[0...index]
        previous = headers[index - 1]
        return false unless header.index == previous.index + 1
        return false unless header.prev_hash == previous.hash
        return false unless header.difficulty == Difficulty.retarget_headers(ancestors)
        return false unless Difficulty.valid_header_timestamp?(header.timestamp, ancestors, now)
        return false unless header.hash_matches? && header.pow_valid?
      end

      true
    end
  end
end
