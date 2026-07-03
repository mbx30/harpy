require "kemal"
require "log"
require "./config"
require "./rate_limit"

module Harpy
  module Server
    extend self

    Log = ::Log.for("harpy.server")

    @@chain : Chain? = nil
    @@storage_path = Config.storage_path
    @@api_key : String? = Config.api_key

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
      @@chain = nil
      @@storage_path = storage_path
      @@api_key = api_key
    end

    def configure_kemal!(rate_limiter : RateLimiter = RateLimiter.from_env)
      Kemal.config do |config|
        config.max_request_body_size = Config.max_request_body_bytes
        config.host_binding = Config.bind_host
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

      get "/health" do
        {
          valid:         chain.valid?,
          last_saved_at: last_saved_at.try(&.to_s),
        }.to_json
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
        index = env.params.url["index"].to_i
        block = chain.blocks.find { |candidate| candidate.index == index }

        unless block
          halt env, status_code: 404, response: %({"error":"block not found"})
        end

        block.to_json
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

        unless pubkey_field.is_a?(String) && pubkey_field.size == 64
          halt env, status_code: 400, response: %({"error":"miner_pubkey must be 64-char hex Ed25519 public key"})
        end

        miner_pubkey = pubkey_field
        selected = chain.mempool.select_for_block(
          chain.tip,
          miner_pubkey,
          chain.utxo_set,
          chain.next_difficulty,
        )
        new_block = Miner.mine_from_mempool(chain, miner_pubkey, verbose: true)

        unless chain.append!(new_block)
          Log.warn { "block_rejected index=#{new_block.index} prev_hash=#{new_block.prev_hash}" }
          halt env, status_code: 422, response: %({"error":"block rejected by chain validation"})
        end

        chain.mempool.remove_txids(selected.map(&.txid))
        Storage.save(chain, @@storage_path)
        Log.info { "block_accepted index=#{new_block.index} hash=#{new_block.hash} height=#{chain.height}" }
        new_block.to_json
      end
    end

    def start(
      storage_path : String = Config.storage_path,
      api_key : String? = Config.api_key,
      rate_limiter : RateLimiter = RateLimiter.from_env,
    )
      reset!(storage_path, api_key)
      configure_kemal!(rate_limiter)
      register_routes!
      Kemal.run
    end
  end
end
