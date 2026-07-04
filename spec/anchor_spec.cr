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
    root = Harpy::Anchor.pending_root

    Harpy::Anchor.seal!(7)
    Harpy::Anchor.pending.should be_empty

    records.each do |r|
      info = Harpy::Anchor.proof_for(r)
      info.should_not be_nil
      info.not_nil!.block_index.should eq(7)
      Harpy::Merkle.verify_proof(r, info.not_nil!.proof, root).should be_true
    end
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

    anchor_root = Harpy::Anchor.pending_root
    block = Harpy::Miner.mine_from_mempool(chain, pubkey, anchor_root: anchor_root)
    chain.append!(block).should be_true
    Harpy::Anchor.seal!(block.index)

    block.anchor_root.should eq(anchor_root)
    block.anchor_root.should_not be_empty

    records.each do |r|
      info = Harpy::Anchor.proof_for(r).not_nil!
      sealing = chain.blocks[info.block_index]
      Harpy::Spv.verify_anchor(r, info.proof, sealing.header).should be_true
    end

    # A record that was never anchored must not verify against this block.
    reference = Harpy::Anchor.proof_for(records[0]).not_nil!
    sealing = chain.blocks[reference.block_index]
    Harpy::Spv.verify_anchor(rec("forged"), reference.proof, sealing.header).should be_false
  end
end
