require "./spec_helper"

private class FragmentedReadIO < IO
  def initialize(@inner : IO, @chunk_size : Int32 = 2)
  end

  def read(slice : Bytes) : Int32
    @inner.read(slice[0, Math.min(slice.size, @chunk_size)])
  end

  def write(slice : Bytes) : Nil
    raise IO::Error.new("read-only test IO")
  end
end

private def with_p2p_test_network(&)
  port = 9700 + Random.rand(200)
  path = File.tempname
  chain = Harpy::SpecHelpers.build_chain(1)
  Harpy::Storage.save(chain, path)
  network = Harpy::P2p::Network.new(
    chain,
    path,
    port,
    handshake_timeout: 250.milliseconds,
    frame_read_timeout: 250.milliseconds,
    write_timeout: 250.milliseconds,
  )
  network.start
  sleep 50.milliseconds

  begin
    yield network, port
  ensure
    network.stop
    File.delete?(path) if File.exists?(path)
  end
end

private def p2p_test_client(port : Int32) : TCPSocket
  socket = TCPSocket.new("127.0.0.1", port)
  socket.read_timeout = 1.second
  socket.write_timeout = 1.second
  socket
end

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

  it "rejects an unknown-parent block when the bounded pool is full" do
    pool = Harpy::P2p::OrphanPool.new
    chain = Harpy::SpecHelpers.build_chain(1)

    Harpy::P2p::OrphanPool::MAX_SIZE.times do |index|
      block = Harpy::Miner.mine(
        Harpy::Block.new(index + 1, Time.utc.to_s, [] of Harpy::BlockTx, Digest::SHA256.hexdigest("parent-#{index}"), 0),
      )
      pool.add(block).should be_true
    end

    overflow = Harpy::Miner.mine(
      Harpy::Block.new(999, Time.utc.to_s, [] of Harpy::BlockTx, Digest::SHA256.hexdigest("overflow-parent"), 0),
    )
    chain.accept_block!(overflow, pool).should eq(Harpy::Chain::BlockAcceptResult::Rejected)
    pool.size.should eq(Harpy::P2p::OrphanPool::MAX_SIZE)
  end

  it "preserves child lookup when an orphan parent joins the active chain" do
    pool = Harpy::P2p::OrphanPool.new
    transactions = Harpy::SpecHelpers.mined_genesis(difficulty: 0).transactions
    parent = Harpy::Miner.mine(Harpy::Block.new(1, Time.utc.to_s, transactions, "missing", 0))
    child = Harpy::Miner.mine(Harpy::Block.new(2, (Time.utc + 1.second).to_s, transactions, parent.hash, 0))

    pool.add(parent).should be_true
    pool.add(child).should be_true
    pool.remove(parent.hash).should eq(parent)
    pool.children_of(parent.hash).map(&.hash).should eq([child.hash])
  end

  it "rejects a malformed orphan before it can poison parent processing" do
    chain = Harpy::SpecHelpers.build_chain(1)
    fork = Harpy::SpecHelpers.extend_fork_from(chain.tip, 2, seconds_between: 60)
    parent = fork.blocks[1]
    poison_coinbase = Harpy::CoinbaseTx.new(outputs: [] of Harpy::TxOutput, height: 2_u32)
    poison = Harpy::Miner.mine(
      Harpy::Block.new(
        2,
        (Harpy::Difficulty.parse_timestamp(parent.timestamp).not_nil! + 60.seconds).to_s(Harpy::Difficulty::TIMESTAMP_FORMAT),
        [poison_coinbase] of Harpy::BlockTx,
        parent.hash,
        fork.next_difficulty,
      ),
    )
    pool = Harpy::P2p::OrphanPool.new

    chain.accept_block!(poison, pool).should eq(Harpy::Chain::BlockAcceptResult::Rejected)
    pool.size.should eq(0)
    Harpy::State.validate_block_transactions(poison, chain.utxo_set).should be_false
    chain.accept_block!(parent, pool).should eq(Harpy::Chain::BlockAcceptResult::Connected)
    chain.height.should eq(2)
  end

  it "rejects overflowing orphan output totals without mutating the parent path" do
    chain = Harpy::SpecHelpers.build_chain(1)
    genesis_output = Harpy::OutPoint.new(chain.tip.transactions.first.txid, 0_u32)
    poison_tx = Harpy::Transaction.new(
      inputs: [Harpy::TxInput.new(genesis_output)],
      outputs: [
        Harpy::TxOutput.new(UInt64::MAX, Harpy::Economics.genesis_pubkey),
        Harpy::TxOutput.new(UInt64::MAX, Harpy::Economics.genesis_pubkey),
      ],
    )
    poison_coinbase = Harpy::CoinbaseTx.new(
      outputs: [Harpy::TxOutput.new(Harpy::Economics::BLOCK_REWARD, Harpy::Economics.genesis_pubkey)],
      height: 2_u32,
    )
    poison = Harpy::Miner.mine(
      Harpy::Block.new(
        2,
        Harpy::Difficulty.next_timestamp(chain.blocks),
        [poison_coinbase, poison_tx] of Harpy::BlockTx,
        Digest::SHA256.hexdigest("unknown-parent"),
        0,
      ),
    )
    pool = Harpy::P2p::OrphanPool.new

    chain.accept_block!(poison, pool).should eq(Harpy::Chain::BlockAcceptResult::Rejected)
    pool.size.should eq(0)
    Harpy::State.validate_tx(poison_tx, chain.utxo_set, 100_u32).should be_false
    chain.height.should eq(1)
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
    peer = "127.0.0.1"

    reputation.record_inv(peer, Harpy::P2p::Reputation::MAX_INV_HASHES_PER_WINDOW).should be_true
    reputation.record_inv(peer, 1).should be_false

    reputation.deprioritized?(peer).should be_true
  end

  it "resets the inventory hash budget after ten seconds" do
    reputation = Harpy::P2p::Reputation.new
    peer = "127.0.0.1"
    start = Time.utc

    reputation.record_inv(peer, 50, start).should be_true
    reputation.record_inv(peer, 1, start + 11.seconds).should be_true
  end

  it "caps block response requests and bytes per ten-second window" do
    reputation = Harpy::P2p::Reputation.new
    peer = "198.51.100.20"
    start = Time.utc

    Harpy::P2p::Reputation::MAX_BLOCK_REQUESTS_PER_WINDOW.times do
      reputation.record_block_response(peer, 1024, start).should be_true
    end
    reputation.record_block_response(peer, 1024, start).should be_false
    reputation.record_block_response(
      "198.51.100.21",
      Harpy::P2p::Reputation::MAX_BLOCK_BYTES_PER_REQUEST + 1,
      start,
    ).should be_false
    reputation.record_block_response(peer, 1024, start + 11.seconds).should be_true
  end

  it "caps sync-control replay attempts per canonical IP" do
    reputation = Harpy::P2p::Reputation.new
    peer = "198.51.100.30"
    start = Time.utc

    Harpy::P2p::Reputation::MAX_SYNC_CONTROLS_PER_WINDOW.times do
      reputation.record_sync_control(peer, start).should be_true
    end
    reputation.record_sync_control(peer, start).should be_false
    reputation.record_sync_control(peer, start + 11.seconds).should be_true
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
    identity = "127.0.0.1"
    peer = Harpy::P2p::Peer.new(address, address, identity)
    manager.register(peer).should be_true

    Harpy::P2p::PeerManager::BAN_THRESHOLD.times do
      manager.record_misbehavior(identity)
    end

    manager.banned?(identity).should be_true
    manager.register(Harpy::P2p::Peer.new("#{identity}:9555", "#{identity}:9555", identity)).should be_false
  end

  it "accumulates ban enforcement across source-port reconnects" do
    manager = Harpy::P2p::PeerManager.new
    identity = "203.0.113.10"

    Harpy::P2p::PeerManager::BAN_THRESHOLD.times do |index|
      id = "#{identity}:#{9000 + index}"
      peer = Harpy::P2p::Peer.new(id, id, identity)
      manager.register(peer) if manager.can_accept(Harpy::P2p::PeerDirection::Inbound, identity)
      manager.record_misbehavior(identity)
      manager.disconnect(id)
    end

    manager.banned?(identity).should be_true
    fresh_id = "#{identity}:9999"
    manager.register(Harpy::P2p::Peer.new(fresh_id, fresh_id, identity)).should be_false
  end

  it "atomically enforces two peers per /16" do
    manager = Harpy::P2p::PeerManager.new

    2.times do |index|
      identity = "10.20.#{index}.1"
      manager.register(Harpy::P2p::Peer.new("#{identity}:#{9000 + index}", identity, identity)).should be_true
    end

    identity = "10.20.99.1"
    manager.register(Harpy::P2p::Peer.new("#{identity}:9999", identity, identity)).should be_false
    manager.inbound_count.should eq(2)
  end

  it "enforces the inbound slot limit and releases slots on disconnect" do
    manager = Harpy::P2p::PeerManager.new

    Harpy::P2p::PeerManager::MAX_INBOUND.times do |index|
      identity = "10.#{index}.0.1"
      id = "#{identity}:#{9000 + index}"
      manager.register(Harpy::P2p::Peer.new(id, id, identity)).should be_true
    end

    overflow_identity = "192.168.0.1"
    overflow_id = "#{overflow_identity}:9999"
    manager.register(Harpy::P2p::Peer.new(overflow_id, overflow_id, overflow_identity)).should be_false
    manager.disconnect("10.0.0.1:9000")
    manager.inbound_count.should eq(Harpy::P2p::PeerManager::MAX_INBOUND - 1)
    manager.register(Harpy::P2p::Peer.new(overflow_id, overflow_id, overflow_identity)).should be_true
  end

  it "preserves a hostname-configured outbound anchor after IP canonicalization" do
    guard = Harpy::P2p::EclipseGuard.new(["trusted.example:9333"])
    manager = Harpy::P2p::PeerManager.new(guard)

    2.times do |index|
      identity = "10.40.#{index}.1"
      id = "#{identity}:#{9000 + index}"
      manager.register(
        Harpy::P2p::Peer.new(id, id, identity, direction: Harpy::P2p::PeerDirection::Outbound),
      ).should be_true
    end

    anchor_identity = "10.40.99.1"
    anchor_id = "#{anchor_identity}:9333"
    manager.register(
      Harpy::P2p::Peer.new(
        anchor_id,
        "trusted.example:9333",
        anchor_identity,
        direction: Harpy::P2p::PeerDirection::Outbound,
        anchor: true,
      ),
    ).should be_true
    manager.eviction_candidate.should_not eq(anchor_identity)
  end
end

describe "P2P protocol validation" do
  it "includes protocol v2 and genesis in both handshake directions" do
    genesis = "ab" * 32
    request = Harpy::P2p::Message.handshake(genesis, 4, "cd" * 32)
    response = Harpy::P2p::Message.handshake_ack(genesis, 4, "cd" * 32)

    request.version.should eq(2)
    response.version.should eq(2)
    request.genesis_hash.should eq(genesis)
    response.genesis_hash.should eq(genesis)
  end

  it "encodes a bounded ancestor-first block request by height" do
    request = Harpy::P2p::Message.get_blocks_by_index(123, 50)

    request.type.should eq("getblocksbyindex")
    request.index.should eq(123)
    request.count.should eq(50)
  end

  it "encodes and validates a bounded common-ancestor locator" do
    locator = [Digest::SHA256.hexdigest("tip"), Digest::SHA256.hexdigest("genesis")]
    request = Harpy::P2p::Message.get_blocks_after(locator, 50)

    Harpy::P2p.valid_locator?(locator).should be_true
    request.type.should eq("getblocksafter")
    request.locator.should eq(locator)
    request.count.should eq(50)
    Harpy::P2p.valid_locator?(Array.new(33) { |index| Digest::SHA256.hexdigest(index.to_s) }).should be_false
  end

  it "rejects oversized, malformed, and duplicate inventory" do
    valid = (0...50).map { |index| Digest::SHA256.hexdigest("inv-#{index}") }

    Harpy::P2p.valid_inventory?(valid).should be_true
    Harpy::P2p.valid_inventory?(valid + [Digest::SHA256.hexdigest("overflow")]).should be_false
    Harpy::P2p.valid_inventory?(["not-a-hash"]).should be_false
    Harpy::P2p.valid_inventory?([valid.first, valid.first]).should be_false
  end
end

describe "P2P attack regressions" do
  it "rejects an unsolicited sync session without replaying a candidate chain" do
    with_p2p_test_network do |network, port|
      client = p2p_test_client(port)
      Harpy::P2p::Wire.write(
        client,
        Harpy::P2p::Message.handshake(
          network.chain.genesis_hash,
          network.chain.height,
          network.chain.tip.hash,
        ),
      )
      Harpy::P2p::Wire.read(client).not_nil!.type.should eq("handshake_ack")

      Harpy::P2p::Wire.write(
        client,
        Harpy::P2p::Message.sync_begin(network.chain.height, network.chain.tip.hash),
      )
      candidate = Harpy::Miner.mine_from_mempool(
        network.chain,
        Harpy::Economics.genesis_pubkey,
        verbose: false,
      )
      Harpy::P2p::Wire.write(client, Harpy::P2p::Message.sync_block_payload(candidate))

      rejection = Harpy::P2p::Wire.read(client).not_nil!
      rejection.type.should eq("reject")
      rejection.reason.should eq("invalid sync block")
      network.chain.height.should eq(1)
      network.peer_manager.reputation.score("127.0.0.1").should be < Harpy::P2p::Reputation::INITIAL_SCORE
      client.close
    end
  end

  it "closes a peer advertising protocol version 999" do
    with_p2p_test_network do |network, port|
      client = p2p_test_client(port)
      Harpy::P2p::Wire.write(
        client,
        Harpy::P2p::Message.new(
          "handshake",
          version: 999,
          genesis_hash: network.chain.genesis_hash,
          height: 1,
          tip_hash: network.chain.tip.hash,
        ),
      )

      Harpy::P2p::Wire.read(client).should be_nil
      sleep 50.milliseconds
      network.peer_manager.inbound_count.should eq(0)
      network.peer_manager.reputation.score("127.0.0.1").should be < Harpy::P2p::Reputation::INITIAL_SCORE
      client.close
    end
  end

  it "limits fifty pre-handshake connections from one IP to two /16 slots" do
    with_p2p_test_network do |network, port|
      clients = [] of TCPSocket
      50.times do
        begin
          clients << p2p_test_client(port)
        rescue IO::Error
        end
      end

      sleep 100.milliseconds
      network.peer_manager.inbound_count.should be <= Harpy::P2p::EclipseGuard::MAX_PER_SUBNET
      clients.each(&.close)
    end
  end

  it "disconnects a peer that never completes its handshake" do
    with_p2p_test_network do |network, port|
      client = p2p_test_client(port)
      sleep 350.milliseconds

      network.peer_manager.inbound_count.should eq(0)
      client.close
    end
  end

  it "disconnects a handshaken peer after the frame-read timeout" do
    with_p2p_test_network do |network, port|
      client = p2p_test_client(port)
      Harpy::P2p::Wire.write(
        client,
        Harpy::P2p::Message.handshake(network.chain.genesis_hash, network.chain.height, network.chain.tip.hash),
      )
      ack = Harpy::P2p::Wire.read(client).not_nil!
      ack.type.should eq("handshake_ack")
      ack.version.should eq(Harpy::P2p::PROTOCOL_VERSION)
      ack.genesis_hash.should eq(network.chain.genesis_hash)

      sleep 350.milliseconds
      network.peer_manager.inbound_count.should eq(0)
      client.close
    end
  end

  it "rejects and penalizes a 200-hash inventory amplification attempt" do
    with_p2p_test_network do |network, port|
      client = p2p_test_client(port)
      Harpy::P2p::Wire.write(
        client,
        Harpy::P2p::Message.handshake(network.chain.genesis_hash, network.chain.height, network.chain.tip.hash),
      )
      Harpy::P2p::Wire.read(client).not_nil!.type.should eq("handshake_ack")

      hashes = (0...200).map { |index| Digest::SHA256.hexdigest("amplify-#{index}") }
      Harpy::P2p::Wire.write(client, Harpy::P2p::Message.inv(hashes))
      rejection = Harpy::P2p::Wire.read(client).not_nil!

      rejection.type.should eq("reject")
      network.peer_manager.reputation.score("127.0.0.1").should be < Harpy::P2p::Reputation::INITIAL_SCORE
      client.close
    end
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

  it "reads a valid frame fragmented across short TCP-style reads" do
    framed = IO::Memory.new
    message = Harpy::P2p::Message.inv([Digest::SHA256.hexdigest("fragmented")])
    Harpy::P2p::Wire.write(framed, message)
    fragmented = FragmentedReadIO.new(IO::Memory.new(framed.to_slice), 1)

    Harpy::P2p::Wire.read(fragmented).not_nil!.hashes.should eq(message.hashes)
  end
end
