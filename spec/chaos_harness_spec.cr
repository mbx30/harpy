require "./spec_helper"

# Chaos harness (MIC-76): inject consensus-layer faults — network partition +
# heal, node crash/restart, and Byzantine (invalid) blocks — and assert the node
# converges to the most-work chain with a consistent UTXO set afterward.
#
# This exercises the reorg + per-block undo path (src/harpy/chain.cr,
# src/harpy/state.cr) deterministically and cross-platform. Socket-level fault
# injection against real multi-node clusters (Pumba/ChaosETH-style) is the
# follow-up, tied to the persistent testnet (MIC-74).

private GPK = Harpy::Economics.genesis_pubkey

private def assert_utxo_consistent(chain : Harpy::Chain)
  # Invariant I7: replaying the same blocks from genesis yields the same UTXO set.
  fresh = Harpy::Chain.new(chain.blocks.dup)
  chain.utxo_set.size.should eq(fresh.utxo_set.size)
  chain.utxo_set.balance(GPK).should eq(fresh.utxo_set.balance(GPK))
end

describe "chaos harness (MIC-76)" do
  it "partition + heal: converges to the heaviest fork with a consistent UTXO set" do
    main = Harpy::SpecHelpers.build_chain(3, difficulty: 0)
    genesis = main.blocks.first

    # A competing partition mined a longer (heavier) chain from the same genesis.
    fork = Harpy::SpecHelpers.extend_fork_from(genesis, 5, "partition")
    fork.cumulative_work.should be > main.cumulative_work

    # Heal: fork choice reorgs the node onto the heaviest chain.
    main.replace_if_more_work_valid!(fork.blocks).should be_true
    main.height.should eq(5)
    main.valid?.should be_true
    assert_utxo_consistent(main)

    # Supply conservation (I1/I3): only BLOCK_REWARD is minted per block.
    main.utxo_set.balance(GPK).should eq(Harpy::Economics::BLOCK_REWARD * 5)
  end

  it "does not reorg to an equal-or-lesser-work partition" do
    main = Harpy::SpecHelpers.build_chain(4, difficulty: 0)
    genesis = main.blocks.first
    weaker = Harpy::SpecHelpers.extend_fork_from(genesis, 3, "weaker")

    main.replace_if_more_work_valid!(weaker.blocks).should be_false
    main.height.should eq(4)
    assert_utxo_consistent(main)
  end

  it "crash/restart: undoing the tip and re-applying restores the exact UTXO set" do
    chain = Harpy::SpecHelpers.build_chain(4, difficulty: 0)
    before_size = chain.utxo_set.size
    before_balance = chain.utxo_set.balance(GPK)
    tip = chain.tip

    # Crash loses the tip block; restart replays it from the persisted chain.
    chain.undo_block!.should be_true
    chain.height.should eq(3)
    chain.append!(tip).should be_true
    chain.height.should eq(4)

    chain.utxo_set.size.should eq(before_size)
    chain.utxo_set.balance(GPK).should eq(before_balance)
    assert_utxo_consistent(chain)
  end

  it "Byzantine block: a tampered block is rejected and the chain is unchanged" do
    chain = Harpy::SpecHelpers.build_chain(3, difficulty: 0)
    valid_next = Harpy::Miner.mine_from_mempool(chain, GPK)
    byzantine = Harpy::SpecHelpers.tamper_block(valid_next, "hash")

    chain.append!(byzantine).should be_false
    chain.height.should eq(3)
    assert_utxo_consistent(chain)
  end

  it "Byzantine fork: a heavier chain containing one invalid block is rejected wholesale" do
    main = Harpy::SpecHelpers.build_chain(2, difficulty: 0)
    genesis = main.blocks.first
    fork = Harpy::SpecHelpers.extend_fork_from(genesis, 5, "byz")
    corrupted = fork.blocks.dup
    corrupted[2] = Harpy::SpecHelpers.tamper_block(corrupted[2], "merkle_root")

    main.replace_if_more_work_valid!(corrupted).should be_false
    main.height.should eq(2)
    assert_utxo_consistent(main)
  end
end
