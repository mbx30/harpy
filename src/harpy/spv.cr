require "./merkle"
require "./block_header"

module Harpy
  # Simplified Payment Verification: confirm a transaction is committed to a block
  # using only the block *header* and a Merkle inclusion proof — no full node, no
  # transaction bodies. This is the client side of the anchoring endgame
  # (hash-on-chain, data off-chain).
  module Spv
    extend self

    # A transaction is included in `header`'s block iff:
    #   1. the header's own hash matches its canonical preimage (untampered), and
    #   2. the header satisfies its proof-of-work, and
    #   3. the Merkle proof reconstructs the header's `merkle_root` from `txid`.
    def verify_inclusion(txid : String, proof : Array(Merkle::ProofStep), header : BlockHeader) : Bool
      return false unless header.hash_matches?
      return false unless header.pow_valid?

      Merkle.verify_proof(txid, proof, header.merkle_root)
    end

    # An anchored record hash is committed to `header`'s block iff the header is
    # untampered, satisfies PoW, and the proof reconstructs its `anchor_root`.
    # This is the client-side check for the Merkle anchoring API (MIC-81).
    def verify_anchor(record_hash : String, proof : Array(Merkle::ProofStep), header : BlockHeader) : Bool
      return false unless header.hash_matches?
      return false unless header.pow_valid?
      return false if header.anchor_root.empty?

      Merkle.verify_proof(record_hash, proof, header.anchor_root)
    end

    # Verify a contiguous run of headers links by `prev_hash` and each satisfies
    # PoW — the header-chain a light client syncs before checking inclusions.
    def verify_header_chain(headers : Array(BlockHeader)) : Bool
      return true if headers.empty?
      return false unless headers.first.hash_matches? && headers.first.pow_valid?

      headers.each_cons(2).all? do |(prev, cur)|
        cur.hash_matches? && cur.pow_valid? && cur.prev_hash == prev.hash
      end
    end
  end
end
