require "./spec_helper"

describe Harpy::P2p::OrphanPool do
  it "stores and retrieves orphan blocks by parent hash" do
    pool = Harpy::P2p::OrphanPool.new
    genesis = Harpy::SpecHelpers.mined_genesis
    orphan = Harpy::Miner.mine(
      Harpy::Block.new(1, Time.utc.to_s, genesis.transactions, "missing-parent", 0),
    )

    pool.add(orphan).should be_true
    pool.children_of("missing-parent").map(&.hash).should eq([orphan.hash])
  end

  it "enforces a maximum pool size" do
    pool = Harpy::P2p::OrphanPool.new
    Harpy::P2p::OrphanPool::MAX_SIZE.times do |index|
      block = Harpy::Block.new(index, Time.utc.to_s, [] of Harpy::BlockTx, "p#{index}", 0)
      pool.add(block).should be_true
    end

    overflow = Harpy::Block.new(999, Time.utc.to_s, [] of Harpy::BlockTx, "overflow", 0)
    pool.add(overflow).should be_false
  end
end

describe "chain reorg with undo data" do
  it "unwinds UTXO changes when reorganizing to a heavier fork" do
    main = Harpy::SpecHelpers.build_chain(3)
    genesis = main.blocks.first
    heavier_fork = Harpy::SpecHelpers.extend_fork_from(genesis, 4, "heavier")

    main.reorg_to!(heavier_fork.blocks).should be_true
    main.height.should eq(4)
    main.valid?.should be_true
    main.utxo_set.size.should eq(heavier_fork.utxo_set.size)
  end

  it "restores spent UTXOs when undoing a block" do
    chain = Harpy::SpecHelpers.build_chain(2)
    before = chain.utxo_set.size

    chain.undo_block!.should be_true
    chain.height.should eq(1)
    chain.utxo_set.size.should be < before
  end
end

describe Harpy::P2p::Reputation do
  it "penalizes peers that flood inv messages" do
    reputation = Harpy::P2p::Reputation.new
    peer = "127.0.0.1:9333"

    (Harpy::P2p::Reputation::MAX_INV_PER_WINDOW + 1).times do
      reputation.record_inv(peer)
    end

    reputation.deprioritized?(peer).should be_true
  end
end

describe Harpy::P2p::Eclipse do
  it "flags eclipse risk when all peers share one /16 subnet" do
    peers = ["10.0.0.1:9333", "10.0.0.2:9333", "10.0.0.3:9333"]
    status = Harpy::P2p::Eclipse.assess(peers)

    status.at_risk.should be_true
    status.distinct_subnets.should eq(1)
  end

  it "accepts diverse peer subnets as healthy" do
    peers = ["10.0.0.1:9333", "192.168.1.2:9333"]
    status = Harpy::P2p::Eclipse.assess(peers)

    status.at_risk.should be_false
    status.distinct_subnets.should eq(2)
  end
end

describe Harpy::P2p::PeerManager do
  it "bans peers after repeated misbehavior" do
    manager = Harpy::P2p::PeerManager.new
    address = "127.0.0.1:9444"
    peer = Harpy::P2p::Peer.new(address, address)
    manager.register(peer).should be_true

    Harpy::P2p::PeerManager::BAN_THRESHOLD.times do
      manager.record_misbehavior(address)
    end

    manager.banned?(address).should be_true
  end
end

describe Harpy::P2p::Wire do
  it "round-trips framed messages" do
    io = IO::Memory.new
    message = Harpy::P2p::Message.inv(["abc123"])

    Harpy::P2p::Wire.write(io, message)
    io.rewind
    Harpy::P2p::Wire.read(io).not_nil!.hashes.should eq(["abc123"])
  end
end
