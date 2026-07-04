require "digest/sha256"

module Harpy
  module Merkle
    extend self

    # One step of a Merkle inclusion path: a sibling hash and whether it sits to
    # the left of the running hash (which side to concatenate on when verifying).
    alias ProofStep = NamedTuple(hash: String, left: Bool)

    def root(txids : Array(String)) : String
      return Digest::SHA256.hexdigest("") if txids.empty?

      layer = txids.map { |id| hex_to_bytes(id) }
      while layer.size > 1
        layer = pair_layer(layer)
      end

      layer.first.hexstring
    end

    # Build the inclusion proof for the leaf at `index`: the sibling hash at each
    # level from leaf up to the root. Uses the same odd-count duplication rule as
    # `root`, so `verify_proof` reconstructs exactly the root `root` produces.
    def proof(txids : Array(String), index : Int32) : Array(ProofStep)
      raise ArgumentError.new("index out of range") if index < 0 || index >= txids.size

      steps = [] of ProofStep
      layer = txids.map { |id| hex_to_bytes(id) }
      idx = index

      while layer.size > 1
        padded = layer.dup
        padded << padded.last if padded.size.odd?

        sibling = idx.even? ? idx + 1 : idx - 1
        steps << {hash: padded[sibling].hexstring, left: idx.odd?}

        layer = pair_layer(layer)
        idx //= 2
      end

      steps
    end

    # Recompute the root from a leaf txid and its inclusion proof, and compare to
    # the expected root. A single-leaf tree has an empty proof and root == leaf.
    def verify_proof(leaf_txid : String, proof : Array(ProofStep), root : String) : Bool
      current = hex_to_bytes(leaf_txid)

      proof.each do |step|
        sibling = hex_to_bytes(step[:hash])
        combined = step[:left] ? sibling + current : current + sibling
        current = Digest::SHA256.digest(combined)
      end

      current.hexstring == root
    rescue
      false
    end

    private def pair_layer(layer : Array(Bytes)) : Array(Bytes)
      padded = layer.dup
      padded << padded.last if padded.size.odd?

      pairs = [] of Bytes
      padded.each_slice(2) do |(left, right)|
        pairs << Digest::SHA256.digest(left + right)
      end
      pairs
    end

    private def hex_to_bytes(hex : String) : Bytes
      hex.hexbytes
    end
  end
end
