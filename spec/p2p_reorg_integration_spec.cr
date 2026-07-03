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
