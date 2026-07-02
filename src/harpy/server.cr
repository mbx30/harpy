require "kemal"

module Harpy
  module Server
    extend self

    @@chain : Chain? = nil
    @@storage_path = Storage::DEFAULT_PATH

    def chain : Chain
      @@chain ||= Storage.load_or_genesis(@@storage_path)
    end

    def start(storage_path : String = Storage::DEFAULT_PATH)
      @@storage_path = storage_path
      chain

      get "/" do
        chain.blocks.to_json
      end

      get "/validate" do
        {
          valid:  chain.valid?,
          height: chain.height,
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

      post "/new-block" do |env|
        body = env.params.json

        unless body.as_h.has_key?("data")
          halt env, status_code: 400, response: %({"error":"missing data field"})
        end

        data = body["data"].as_s

        if data.empty?
          halt env, status_code: 400, response: %({"error":"data cannot be empty"})
        end

        new_block = Miner.mine_next(chain.tip, data, verbose: true)

        unless chain.append!(new_block)
          halt env, status_code: 422, response: %({"error":"block rejected by chain validation"})
        end

        Storage.save(chain)
        new_block.to_json
      end

      Kemal.run
    end
  end
end
