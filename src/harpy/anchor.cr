require "./merkle"

module Harpy
  # Merkle anchoring (MIC-81): applications submit record hashes; Harpy batches the
  # pending set into a Merkle root, commits that root on-chain in the next mined
  # block's `anchor_root` (part of the block's PoW hash), and can then return an
  # inclusion proof for any anchored record. Core pattern: hash-on-chain, data
  # off-chain — the chain proves a record hash existed at a point in time.
  #
  # State is in-memory: the durable commitment is the on-chain `anchor_root`; the
  # record→proof index here is a convenience that does not survive a restart or a
  # reorg that drops a sealing block (documented limitation for the tutorial).
  module Anchor
    extend self

    @@pending = [] of String
    @@sealed = Hash(Int32, Array(String)).new    # block index → anchored record hashes
    @@record_block = Hash(String, Int32).new     # record hash → sealing block index

    # Queue a record hash for the next block. Returns false for a malformed hash.
    def submit(record_hash : String) : Bool
      return false unless valid_hash?(record_hash)

      @@pending << record_hash unless @@pending.includes?(record_hash)
      true
    end

    def pending : Array(String)
      @@pending.dup
    end

    # Merkle root of the current pending batch, or "" when nothing is pending
    # (empty root means the mined block omits `anchor_root` entirely).
    def pending_root : String
      return "" if @@pending.empty?

      Merkle.root(@@pending)
    end

    # Record that `block_index` sealed the current pending batch, then clear it.
    def seal!(block_index : Int32) : Nil
      return if @@pending.empty?

      leaves = @@pending.dup
      @@sealed[block_index] = leaves
      leaves.each { |h| @@record_block[h] = block_index }
      @@pending.clear
    end

    record Proof, block_index : Int32, proof : Array(Merkle::ProofStep)

    # Inclusion proof for a previously anchored record, or nil if unknown.
    def proof_for(record_hash : String) : Proof?
      index = @@record_block[record_hash]?
      return nil unless index

      leaves = @@sealed[index]?
      return nil unless leaves

      position = leaves.index(record_hash)
      return nil unless position

      Proof.new(index, Merkle.proof(leaves, position))
    end

    def reset! : Nil
      @@pending.clear
      @@sealed.clear
      @@record_block.clear
    end

    private def valid_hash?(hash : String) : Bool
      hash.size == 64 && hash.each_char.all? { |c| c.ascii_number? || ('a'..'f').includes?(c) }
    end
  end
end
