require "./spec_helper"

# Build a sealed header committing to `txids` at difficulty 0 (any hash passes PoW).
private def sealed_header(txids : Array(String)) : Harpy::BlockHeader
  root = Harpy::Merkle.root(txids)
  draft = Harpy::BlockHeader.new(1, "2026-01-01 00:00:00 UTC", root, "prevhash", 0, "nonce")
  Harpy::BlockHeader.new(
    draft.index, draft.timestamp, draft.merkle_root,
    draft.prev_hash, draft.difficulty, draft.nonce, draft.computed_hash,
  )
end

private def txid(seed : String) : String
  Digest::SHA256.hexdigest(seed)
end

describe Harpy::Spv do
  describe ".verify_inclusion" do
    it "verifies a committed transaction via header + merkle proof" do
      txids = (0...5).map { |i| txid("spv-#{i}") }
      header = sealed_header(txids)

      txids.each_with_index do |leaf, i|
        proof = Harpy::Merkle.proof(txids, i)
        Harpy::Spv.verify_inclusion(leaf, proof, header).should be_true
      end
    end

    it "verifies inclusion of a real mined coinbase-only block" do
      block = Harpy::SpecHelpers.mined_genesis(difficulty: 0)
      txids = block.transactions.map(&.txid)
      proof = Harpy::Merkle.proof(txids, 0)

      Harpy::Spv.verify_inclusion(txids.first, proof, block.header).should be_true
    end

    it "rejects a transaction not in the block" do
      txids = (0...4).map { |i| txid("in-#{i}") }
      header = sealed_header(txids)
      proof = Harpy::Merkle.proof(txids, 1)

      Harpy::Spv.verify_inclusion(txid("outsider"), proof, header).should be_false
    end

    it "rejects a tampered header whose hash no longer matches" do
      txids = (0...4).map { |i| txid("t-#{i}") }
      good = sealed_header(txids)
      tampered = Harpy::BlockHeader.new(
        good.index, good.timestamp, "0" * 64, good.prev_hash,
        good.difficulty, good.nonce, good.hash,
      )
      proof = Harpy::Merkle.proof(txids, 0)

      Harpy::Spv.verify_inclusion(txids.first, proof, tampered).should be_false
    end
  end

  describe ".verify_header_chain" do
    it "accepts a real mined chain's headers" do
      headers = Harpy::SpecHelpers.build_chain(3).blocks.map(&.header)
      Harpy::Spv.verify_header_chain(headers).should be_true
    end

    it "rejects headers with a broken prev_hash link" do
      headers = Harpy::SpecHelpers.build_chain(3).blocks.map(&.header)
      broken = headers.dup
      # Re-seal a self-consistent header (hash matches its own preimage, PoW ok)
      # that simply doesn't link to its parent — isolates the linkage check.
      draft = Harpy::BlockHeader.new(
        headers[2].index, headers[2].timestamp, headers[2].merkle_root,
        "wrongprev", headers[2].difficulty, headers[2].nonce,
      )
      relinked = Harpy::BlockHeader.new(
        draft.index, draft.timestamp, draft.merkle_root,
        draft.prev_hash, draft.difficulty, draft.nonce, draft.computed_hash,
      )
      relinked.hash_matches?.should be_true
      broken[2] = relinked

      Harpy::Spv.verify_header_chain(broken).should be_false
    end
  end
end
