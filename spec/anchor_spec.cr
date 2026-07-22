require "./spec_helper"

private def rec(seed : String) : String
  Digest::SHA256.hexdigest(seed)
end

describe Harpy::Anchor do
  before_each { Harpy::Anchor.reset! }

  it "queues valid record hashes and rejects malformed ones" do
    Harpy::Anchor.submit(rec("a")).should be_true
    Harpy::Anchor.submit("not-a-hash").should be_false
    Harpy::Anchor.submit("XYZ").should be_false
    Harpy::Anchor.pending.size.should eq(1)
  end

  it "deduplicates identical pending submissions" do
    Harpy::Anchor.submit(rec("dup"))
    Harpy::Anchor.submit(rec("dup"))
    Harpy::Anchor.pending.size.should eq(1)
  end

  it "produces an inclusion proof after sealing that verifies against the anchor root" do
    records = (0...4).map { |i| rec("seal-#{i}") }
    records.each { |r| Harpy::Anchor.submit(r) }
    batch = Harpy::Anchor.take_pending_batch!
    root = batch.not_nil!.root
    block_hash = rec("block-7")

    Harpy::Anchor.seal!(block_hash, batch.not_nil!.leaves)
    Harpy::Anchor.pending.should be_empty

    records.each do |r|
      info = Harpy::Anchor.proof_for(r)
      info.should_not be_nil
      info.not_nil!.block_hash.should eq(block_hash)
      Harpy::Merkle.verify_proof(r, info.not_nil!.proof, root).should be_true
    end
  end

  it "does not seal records submitted after the mining snapshot" do
    Harpy::Anchor.submit(rec("a"))
    batch = Harpy::Anchor.take_pending_batch!
    Harpy::Anchor.submit(rec("b"))

    Harpy::Anchor.seal!(rec("block"), batch.not_nil!.leaves)
    Harpy::Anchor.proof_for(rec("b")).should be_nil
    Harpy::Anchor.pending.size.should eq(1)
  end

  it "returns nil for an unknown record" do
    Harpy::Anchor.proof_for(rec("never")).should be_nil
  end

  it "reports empty pending_root when nothing is queued" do
    Harpy::Anchor.pending_root.should eq("")
  end

  it "end-to-end: seals records into a mined block's anchor_root, verifiable via SPV" do
    Harpy::Anchor.reset!
    chain = Harpy::SpecHelpers.build_chain(1)
    _, verify_key = Harpy::SpecHelpers.generate_keypair
    pubkey = Harpy::Crypto.pubkey_hex(verify_key)
    records = (0...3).map { |i| rec("e2e-#{i}") }
    records.each { |r| Harpy::Anchor.submit(r) }

    batch = Harpy::Anchor.take_pending_batch!
    anchor_root = batch.not_nil!.root
    block = Harpy::Miner.mine_from_mempool(chain, pubkey, anchor_root: anchor_root)
    chain.append!(block).should be_true
    Harpy::Anchor.seal!(block.hash, batch.not_nil!.leaves)

    block.anchor_root.should eq(anchor_root)
    block.anchor_root.should_not be_empty

    records.each do |r|
      info = Harpy::Anchor.proof_for(r).not_nil!
      sealing = chain.block_by_hash(info.block_hash).not_nil!
      headers = chain.blocks[0..sealing.index].map(&.header)
      Harpy::Spv.verify_anchor(
        r,
        info.proof,
        headers,
        sealing.index,
        chain.genesis_hash,
        chain.tip.hash,
      ).should be_true
    end

    reference = Harpy::Anchor.proof_for(records[0]).not_nil!
    sealing = chain.block_by_hash(reference.block_hash).not_nil!
    headers = chain.blocks[0..sealing.index].map(&.header)
    Harpy::Spv.verify_anchor(
      rec("forged"),
      reference.proof,
      headers,
      sealing.index,
      chain.genesis_hash,
      chain.tip.hash,
    ).should be_false
  end

  it "drops stale index entries after reorg pruning" do
    orphan_hash = rec("orphan-block")
    record = rec("stale-record")
    Harpy::Anchor.seal!(orphan_hash, [record])

    Harpy::Anchor.proof_for(record).should_not be_nil
    Harpy::Anchor.prune_orphaned!(Set{"ab" * 32})
    Harpy::Anchor.proof_for(record).should be_nil
  end
end
