require "kemal"
require "log"
require "./config"
require "./rate_limit"
require "./p2p"

module Harpy
  module Server
    extend self

    Log = ::Log.for("harpy.server")

    @@chain : Chain? = nil
    @@storage_path = Config.storage_path
    @@api_key : String? = nil
    @@p2p : P2p::Network? = nil
    @@chain_mutex = Mutex.new

    def chain : Chain
      @@chain ||= Storage.load_or_genesis(@@storage_path)
    end

    def last_saved_at : Time?
      return nil unless File.exists?(@@storage_path)

      File.info(@@storage_path).modification_time
    end

    def reset!(
      storage_path : String = Config.storage_path,
      api_key : String? = Config.api_key,
    )
      @@p2p.try &.stop
      @@p2p = nil
      @@chain = nil
      @@storage_path = storage_path
      @@api_key = api_key
      Anchor.reset!
      MineJobs.reset!
    end

    # Raised when a mined block fails chain validation on append.
    class MiningRejected < Exception; end

    # Mine one block from the mempool and append it: the shared core of the
    # synchronous route and the async job worker. Holds the chain mutex so
    # mining never interleaves with P2P block application.
    def mine_block!(miner_pubkey : String) : Block
      @@chain_mutex.synchronize do
        selected = chain.mempool.select_for_block(
          chain.tip,
          miner_pubkey,
          chain.utxo_set,
          chain.next_difficulty,
        )
        batch = Anchor.take_pending_batch!
        anchor_root = batch.try &.root || ""
        sealed_leaves = batch.try &.leaves || [] of String
        new_block = Miner.mine_from_mempool(chain, miner_pubkey, verbose: true, anchor_root: anchor_root)

        unless chain.append!(new_block)
          # Restore the batch if mining succeeded but validation rejected the block.
          sealed_leaves.each { |hash| Anchor.submit(hash) unless Anchor.pending.includes?(hash) }
          Log.warn { "block_rejected index=#{new_block.index} prev_hash=#{new_block.prev_hash}" }
          raise MiningRejected.new("block rejected by chain validation")
        end

        chain.mempool.remove_txids(selected.map(&.txid))
        Anchor.seal!(new_block.hash, sealed_leaves)
        Storage.save(chain, @@storage_path)
        @@p2p.try &.broadcast_block(new_block)
        Log.info { "block_accepted index=#{new_block.index} hash=#{new_block.hash} height=#{chain.height}" }
        new_block
      end
    end

    def with_chain(&)
      @@chain_mutex.synchronize do
        yield chain
      end
    end

    def configure_kemal!(rate_limiter : RateLimiter = RateLimiter.from_env)
      Kemal.config do |config|
        config.max_request_body_size = Config.max_request_body_bytes
        config.host_binding = Config.bind_host
        config.port = Config.http_port
      end

      Kemal.config.add_handler RateLimitHandler.new(rate_limiter)

      Kemal.config.add_error_handler(413) do |env, _ex|
        env.response.content_type = "application/json"
        %({"error":"request body too large"})
      end
    end

    def register_routes!
      get "/" do
        chain.blocks.to_json
      end

      # Branded status dashboard (static; assets under public/design-system/).
      get "/dashboard" do |env|
        send_file env, "public/dashboard.html"
      end

      get "/health" do
        with_chain do |active|
          p2p_status = if network = @@p2p
                         eclipse = network.peer_manager.eclipse_status
                         {
                           enabled:      true,
                           peers:        network.peer_manager.peers.size,
                           orphans:      network.orphan_pool.size,
                           eclipse_risk: eclipse.at_risk,
                           peer_subnets: eclipse.distinct_subnets,
                         }
                       else
                         {enabled: false}
                       end

          {
            valid:         active.valid?,
            last_saved_at: last_saved_at.try(&.to_s),
            p2p:           p2p_status,
          }.to_json
        end
      end

      get "/validate" do
        {
          valid:  chain.valid?,
          height: chain.height,
          work:   chain.cumulative_work,
          tip:    chain.empty? ? nil : chain.tip.hash,
        }.to_json
      end

      get "/block/:index" do |env|
        raw_index = env.params.url["index"]
        index = raw_index.to_i?
        unless index && index >= 0
          env.response.content_type = "application/json"
          halt env, status_code: 400, response: %({"error":"index must be a non-negative integer"})
        end
        block = chain.blocks.find { |candidate| candidate.index == index }

        unless block
          halt env, status_code: 404, response: %({"error":"block not found"})
        end

        block.to_json
      end

      # Light-client header endpoints: sync/verify PoW without transaction bodies.
      get "/header/:index" do |env|
        raw_index = env.params.url["index"]
        index = raw_index.to_i?
        unless index && index >= 0
          env.response.content_type = "application/json"
          halt env, status_code: 400, response: %({"error":"index must be a non-negative integer"})
        end
        block = chain.blocks.find { |candidate| candidate.index == index }

        unless block
          halt env, status_code: 404, response: %({"error":"block not found"})
        end

        block.header.to_json
      end

      get "/headers" do |env|
        blocks = chain.blocks
        raw_from = env.params.query["from"]?
        raw_to = env.params.query["to"]?
        from = raw_from ? raw_from.to_i? : 0
        to = raw_to ? raw_to.to_i? : (blocks.size - 1)
        unless from && to && from >= 0 && to >= 0 && from <= to
          env.response.content_type = "application/json"
          halt env, status_code: 400, response: %({"error":"header range must use non-negative integers with from <= to"})
        end
        blocks.select { |b| b.index >= from && b.index <= to }.map(&.header).to_json
      end

      # SPV inclusion proof: header + Merkle path for a txid, verifiable client-side.
      get "/proof/:index/:txid" do |env|
        raw_index = env.params.url["index"]
        index = raw_index.to_i?
        unless index && index >= 0
          env.response.content_type = "application/json"
          halt env, status_code: 400, response: %({"error":"index must be a non-negative integer"})
        end
        target = env.params.url["txid"]
        block = chain.blocks.find { |candidate| candidate.index == index }

        unless block
          halt env, status_code: 404, response: %({"error":"block not found"})
        end

        txids = block.transactions.map(&.txid)
        position = txids.index(target)

        unless position
          halt env, status_code: 404, response: %({"error":"transaction not found in block"})
        end

        {header: block.header, merkle_proof: Merkle.proof(txids, position)}.to_json
      end

      # Anchoring API (MIC-81): submit a record hash to be committed on-chain.
      post "/anchor" do |env|
        unless Config.write_authorized?(env.request, @@api_key)
          halt env, status_code: 401, response: %({"error":"unauthorized"})
        end

        body = env.params.json
        record_hash = body["record_hash"]?

        unless record_hash.is_a?(String) && Anchor.submit(record_hash)
          halt env, status_code: 400, response: %({"error":"record_hash must be a 64-char hex SHA-256 digest"})
        end

        {pending: Anchor.pending.size}.to_json
      end

      # Return an inclusion proof for an anchored record: proof + sealing header.
      # Verify client-side with Harpy::Spv.verify_anchor.
      get "/anchor/:record_hash" do |env|
        record_hash = env.params.url["record_hash"]
        info = Anchor.proof_for(record_hash)

        unless info
          halt env, status_code: 404, response: %({"error":"record not anchored (unknown or not yet mined)"})
        end

        block = chain.block_by_hash(info.block_hash)
        verification_headers = chain.blocks.map(&.header)
        unless block && Spv.verify_anchor(
                 record_hash,
                 info.proof,
                 verification_headers,
                 block.index,
                 chain.genesis_hash,
                 chain.tip.hash,
               )
          halt env, status_code: 404, response: %({"error":"record not anchored (unknown or not yet mined)"})
        end

        {
          record_hash:  record_hash,
          block_index:  block.index,
          block_hash:   block.hash,
          anchor_root:  block.anchor_root,
          merkle_proof: info.proof,
          header:       block.header,
        }.to_json
      end

      get "/mempool" do
        {transactions: chain.mempool.transactions}.to_json
      end

      post "/tx" do |env|
        unless Config.write_authorized?(env.request, @@api_key)
          halt env, status_code: 401, response: %({"error":"unauthorized"})
        end

        begin
          tx = Transaction.from_json(env.params.json.to_json)
        rescue
          halt env, status_code: 400, response: %({"error":"invalid transaction json"})
        end

        result = chain.mempool.add(tx, chain.utxo_set, chain.height.to_u32)
        case result
        when Mempool::AddResult::Accepted
          {txid: tx.txid}.to_json
        when Mempool::AddResult::Conflict
          halt env, status_code: 409, response: %({"error":"double-spend conflict"})
        else
          halt env, status_code: 400, response: %({"error":"invalid transaction"})
        end
      end

      post "/mine" do |env|
        unless Config.write_authorized?(env.request, @@api_key)
          halt env, status_code: 401, response: %({"error":"unauthorized"})
        end

        body = env.params.json
        unless pubkey_field = body["miner_pubkey"]?
          halt env, status_code: 400, response: %({"error":"missing miner_pubkey field"})
        end

        unless pubkey_field.is_a?(String) && Crypto.valid_pubkey_hex?(pubkey_field)
          halt env, status_code: 400, response: %({"error":"miner_pubkey must be a 64-char lowercase hex Ed25519 public key"})
        end

        miner_pubkey = pubkey_field

        # Async mode (MIC-44): 202 + job id, mined by the worker fiber. CPU
        # abuse on POST is bounded by MineJobs::MAX_QUEUE, not request volume.
        if body["async"]? == true
          job = MineJobs.enqueue(miner_pubkey)
          unless job
            halt env, status_code: 503, response: %({"error":"mining queue full"})
          end
          env.response.status_code = 202
          next {job_id: job.id, state: job.state.to_s, poll: "/mine-jobs/#{job.id}"}.to_json
        end

        begin
          new_block = mine_block!(miner_pubkey)
        rescue MiningRejected
          halt env, status_code: 422, response: %({"error":"block rejected by chain validation"})
        end

        new_block.to_json
      end

      # Poll an async mining job (MIC-44).
      get "/mine-jobs/:id" do |env|
        job = MineJobs.find(env.params.url["id"])

        unless job
          halt env, status_code: 404, response: %({"error":"unknown job id"})
        end

        job.to_json
      end
    end

    def start(
      storage_path : String = Config.storage_path,
      api_key : String? = Config.api_key,
      rate_limiter : RateLimiter = RateLimiter.from_env,
    )
      Config.validate!(api_key)
      reset!(storage_path, api_key)
      configure_kemal!(rate_limiter)
      register_routes!

      if Config.p2p_enabled?
        @@p2p = P2p::Network.new(chain, storage_path, Config.p2p_port, @@chain_mutex)
        @@p2p.not_nil!.start
      end

      spawn { MineJobs.run_worker { |pubkey| mine_block!(pubkey) } }

      Kemal.run
    end
  end
end
