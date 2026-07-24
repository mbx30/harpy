require "./spec_helper"

private def spv_txid(seed : String) : String
  Digest::SHA256.hexdigest(seed)
end

describe Harpy::Spv do
  describe ".verify_inclusion" do
    it "verifies a transaction only after validating the complete trusted header chain" do
      chain = Harpy::SpecHelpers.build_chain(3)

      chain.blocks.each_with_index do |block, index|
        txids = block.transactions.map(&.txid)
        proof = Harpy::Merkle.proof(txids, 0)
        headers = chain.blocks[0..index].map(&.header)

        Harpy::Spv.verify_inclusion(
          txids.first,
          proof,
          headers,
          index,
          chain.genesis_hash,
          headers.last.hash,
        ).should be_true
      end
    end

    it "rejects a transaction not committed to the target block" do
      chain = Harpy::SpecHelpers.build_chain(2)
      target = chain.tip
      proof = Harpy::Merkle.proof(target.transactions.map(&.txid), 0)

      Harpy::Spv.verify_inclusion(
        spv_txid("outsider"),
        proof,
        chain.blocks.map(&.header),
        target.index,
        chain.genesis_hash,
        chain.tip.hash,
      ).should be_false
    end

    it "rejects a tampered target header" do
      chain = Harpy::SpecHelpers.build_chain(2)
      target = chain.tip
      good = target.header
      tampered = Harpy::BlockHeader.new(
        good.index,
        good.timestamp,
        "0" * 64,
        good.prev_hash,
        good.difficulty,
        good.nonce,
        good.hash,
        good.anchor_root,
      )
      headers = chain.blocks.map(&.header)
      headers[-1] = tampered
      proof = Harpy::Merkle.proof(target.transactions.map(&.txid), 0)

      Harpy::Spv.verify_inclusion(
        target.transactions.first.txid,
        proof,
        headers,
        target.index,
        chain.genesis_hash,
        chain.tip.hash,
      ).should be_false
    end

    it "rejects the original forged zero-difficulty proof attack" do
      chain = Harpy::SpecHelpers.build_chain(2, difficulty: 1)
      target = chain.tip
      draft = Harpy::BlockHeader.new(
        target.index,
        target.timestamp,
        target.merkle_root,
        chain.blocks.first.hash,
        0,
        "0",
        anchor_root: target.anchor_root,
      )
      forged = Harpy::BlockHeader.new(
        draft.index,
        draft.timestamp,
        draft.merkle_root,
        draft.prev_hash,
        draft.difficulty,
        draft.nonce,
        draft.computed_hash,
        draft.anchor_root,
      )
      headers = [chain.blocks.first.header, forged]
      proof = Harpy::Merkle.proof(target.transactions.map(&.txid), 0)

      forged.hash_matches?.should be_true
      forged.pow_valid?.should be_true
      Harpy::Spv.verify_inclusion(
        target.transactions.first.txid,
        proof,
        headers,
        target.index,
        chain.genesis_hash,
        chain.tip.hash,
      ).should be_false
    end
  end

  describe ".verify_header_chain" do
    it "accepts a real mined chain's headers" do
      chain = Harpy::SpecHelpers.build_chain(3)
      Harpy::Spv.verify_header_chain(
        chain.blocks.map(&.header),
        chain.genesis_hash,
        chain.tip.hash,
      ).should be_true
    end

    it "rejects an incomplete chain that starts at the target header" do
      chain = Harpy::SpecHelpers.build_chain(2)
      Harpy::Spv.verify_header_chain([chain.tip.header], chain.genesis_hash, chain.tip.hash).should be_false
    end

    it "rejects a caller-supplied genesis hash that is not trusted" do
      chain = Harpy::SpecHelpers.build_chain(2)
      Harpy::Spv.verify_header_chain(
        chain.blocks.map(&.header),
        "0" * 64,
        chain.tip.hash,
      ).should be_false
    end

    it "rejects a self-consistent downgraded genesis against the trusted hash" do
      trusted = Harpy::SpecHelpers.build_chain(1, difficulty: 1)
      original = trusted.blocks.first.header
      draft = Harpy::BlockHeader.new(
        original.index,
        original.timestamp,
        original.merkle_root,
        original.prev_hash,
        0,
        "0",
        anchor_root: original.anchor_root,
      )
      downgraded = Harpy::BlockHeader.new(
        draft.index,
        draft.timestamp,
        draft.merkle_root,
        draft.prev_hash,
        draft.difficulty,
        draft.nonce,
        draft.computed_hash,
        draft.anchor_root,
      )

      downgraded.hash_matches?.should be_true
      downgraded.pow_valid?.should be_true
      Harpy::Spv.verify_header_chain(
        [downgraded],
        trusted.genesis_hash,
        trusted.tip.hash,
      ).should be_false
    end

    it "rejects attacker-sized genesis difficulty without allocating its prefix" do
      trusted = Harpy::SpecHelpers.build_chain(1)
      original = trusted.blocks.first.header
      draft = Harpy::BlockHeader.new(
        original.index,
        original.timestamp,
        original.merkle_root,
        original.prev_hash,
        Int32::MAX,
        "0",
        anchor_root: original.anchor_root,
      )
      hostile = Harpy::BlockHeader.new(
        draft.index,
        draft.timestamp,
        draft.merkle_root,
        draft.prev_hash,
        draft.difficulty,
        draft.nonce,
        draft.computed_hash,
        draft.anchor_root,
      )

      hostile.pow_valid?.should be_false
      Harpy::Spv.verify_header_chain([hostile], hostile.hash, hostile.hash).should be_false
    end

    it "rejects headers with a broken prev_hash link" do
      chain = Harpy::SpecHelpers.build_chain(3)
      headers = chain.blocks.map(&.header)
      original = headers[2]
      draft = Harpy::BlockHeader.new(
        original.index,
        original.timestamp,
        original.merkle_root,
        "wrongprev",
        original.difficulty,
        original.nonce,
        anchor_root: original.anchor_root,
      )
      headers[2] = Harpy::BlockHeader.new(
        draft.index,
        draft.timestamp,
        draft.merkle_root,
        draft.prev_hash,
        draft.difficulty,
        draft.nonce,
        draft.computed_hash,
        draft.anchor_root,
      )

      Harpy::Spv.verify_header_chain(headers, chain.genesis_hash, chain.tip.hash).should be_false
    end

    it "rejects a valid private fork that does not reach the trusted tip" do
      honest = Harpy::SpecHelpers.build_chain(3)
      genesis = honest.blocks.first
      attacker_key = Harpy::Crypto.pubkey_hex(Harpy::SpecHelpers.generate_keypair[1])
      private_fork = Harpy::SpecHelpers.extend_fork_from(
        genesis,
        2,
        seconds_between: 60,
        miner_pubkey: attacker_key,
      )

      Harpy::Spv.verify_header_chain(
        private_fork.blocks.map(&.header),
        honest.genesis_hash,
        honest.tip.hash,
      ).should be_false
    end
  end
end
