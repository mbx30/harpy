require "./spec_helper"
require "socket"

module Harpy::P2p::TestNode
  extend self

  def spawn(port : Int32, storage_path : String, peers : Array(String) = [] of String) : Network
    Harpy::SpecHelpers.with_env("HARPY_P2P_PORT", port.to_s) do
      Harpy::SpecHelpers.with_env("HARPY_P2P_PEERS", peers.join(",")) do
        chain = Harpy::Storage.load_or_genesis(storage_path, verbose: false)
        network = Harpy::P2p::Network.new(chain, storage_path, port)
        network.start
        network
      end
    end
  end
end

describe "3-node reorg integration" do
  it "keeps UTXO sets consistent after a heavier fork propagates" do
    base = 9400 + Random.rand(200)
    paths = Array.new(3) { File.tempname }
    networks = [] of Harpy::P2p::Network

    begin
      shared = Harpy::Chain.genesis_chain(difficulty: 0)
      paths.each { |path| Harpy::Storage.save(shared, path) }

      networks << Harpy::P2p::TestNode.spawn(base, paths[0])
      networks << Harpy::P2p::TestNode.spawn(base + 1, paths[1], ["127.0.0.1:#{base}"])
      networks << Harpy::P2p::TestNode.spawn(base + 2, paths[2], ["127.0.0.1:#{base}"])

      sleep 0.2.seconds

      miner_pubkey = Harpy::Economics.genesis_pubkey
      node_a = networks[0]
      chain_a = node_a.chain

      2.times do
        block = Harpy::Miner.mine_from_mempool(chain_a, miner_pubkey, verbose: false)
        chain_a.append!(block).should be_true
        Harpy::Storage.save(chain_a, paths[0])
        node_a.broadcast_block(block)
        networks[1].handle_incoming_block(block, "test-sync")
        networks[2].handle_incoming_block(block, "test-sync")
        sleep 0.1.seconds
      end

      chain_a.height.should eq(3)
      networks[1].chain.height.should eq(3)

      # Build competing fork on node B from genesis
      chain_b = networks[1].chain
      genesis = chain_a.blocks.first
      fork = Harpy::SpecHelpers.extend_fork_from(genesis, 4, "competing")

      fork.blocks.last(3).each do |block|
        networks[1].handle_incoming_block(block, "local-fork")
        networks[1].broadcast_block(block)
        networks[0].handle_incoming_block(block, "test-sync")
        networks[2].handle_incoming_block(block, "test-sync")
        sleep 0.05.seconds
      end

      sleep 0.3.seconds

      heights = networks.map(&.chain.height)
      utxo_sizes = networks.map(&.chain.utxo_set.size)

      heights.uniq.size.should eq(1)
      utxo_sizes.uniq.size.should eq(1)
      heights.first.should eq(4)
      networks.each { |network| network.chain.valid?.should be_true }
    ensure
      networks.each(&.stop)
      paths.each { |path| File.delete?(path) if File.exists?(path) }
    end
  end
end

describe "P2P reconnect synchronization" do
  it "retries startup races and catches up ancestor-first beyond orphan capacity" do
    base = 9650 + Random.rand(40)
    source_path = File.tempname
    lagging_path = File.tempname
    networks = [] of Harpy::P2p::Network

    begin
      source_chain = Harpy::SpecHelpers.build_chain(155)
      lagging_chain = Harpy::Chain.new([source_chain.blocks.first])
      Harpy::Storage.save(source_chain, source_path)
      Harpy::Storage.save(lagging_chain, lagging_path)

      lagging = Harpy::SpecHelpers.with_env("HARPY_P2P_PEERS", "127.0.0.1:#{base}") do
        network = Harpy::P2p::Network.new(
          lagging_chain,
          lagging_path,
          base + 1,
          outbound_retry_delay: 50.milliseconds,
        )
        network.start
        network
      end
      networks << lagging

      # The first outbound attempt must fail; the retry loop connects after the
      # source listener appears.
      sleep 150.milliseconds
      source = Harpy::P2p::Network.new(source_chain, source_path, base)
      source.start
      networks << source

      400.times do
        break if lagging.chain.height == source_chain.height && lagging.chain.tip.hash == source_chain.tip.hash
        sleep 50.milliseconds
      end

      lagging.chain.height.should eq(155)
      lagging.chain.tip.hash.should eq(source_chain.tip.hash)
      lagging.chain.valid?.should be_true
      lagging.orphan_pool.size.should eq(0)
    ensure
      networks.each(&.stop)
      File.delete?(source_path) if File.exists?(source_path)
      File.delete?(lagging_path) if File.exists?(lagging_path)
    end
  end

  it "negotiates a common ancestor for a fork diverged by more than 100 blocks" do
    base = 9250 + Random.rand(40)
    source_path = File.tempname
    local_path = File.tempname
    networks = [] of Harpy::P2p::Network

    begin
      genesis = Harpy::Miner.mine(
        Harpy::Block.genesis(
          timestamp: (Time.utc - 6.hours).to_s(Harpy::Difficulty::TIMESTAMP_FORMAT),
          difficulty: 0,
        ),
      )
      local_key = Harpy::Crypto.pubkey_hex(Harpy::SpecHelpers.generate_keypair[1])
      source_key = Harpy::Crypto.pubkey_hex(Harpy::SpecHelpers.generate_keypair[1])
      local_chain = Harpy::SpecHelpers.extend_fork_from(
        genesis,
        130,
        seconds_between: 60,
        miner_pubkey: local_key,
      )
      source_chain = Harpy::SpecHelpers.extend_fork_from(
        genesis,
        170,
        seconds_between: 60,
        miner_pubkey: source_key,
      )
      Harpy::Storage.save(source_chain, source_path)
      Harpy::Storage.save(local_chain, local_path)

      local = Harpy::SpecHelpers.with_env("HARPY_P2P_PEERS", "127.0.0.1:#{base}") do
        network = Harpy::P2p::Network.new(
          local_chain,
          local_path,
          base + 1,
          outbound_retry_delay: 50.milliseconds,
        )
        network.start
        network
      end
      networks << local

      sleep 150.milliseconds
      source = Harpy::P2p::Network.new(source_chain, source_path, base)
      source.start
      networks << source

      400.times do
        break if local.chain.height == source_chain.height && local.chain.tip.hash == source_chain.tip.hash
        sleep 50.milliseconds
      end

      local.chain.height.should eq(170)
      local.chain.tip.hash.should eq(source_chain.tip.hash)
      local.chain.valid?.should be_true
      local.orphan_pool.size.should eq(0)
    ensure
      networks.each(&.stop)
      File.delete?(source_path) if File.exists?(source_path)
      File.delete?(local_path) if File.exists?(local_path)
    end
  end
end
