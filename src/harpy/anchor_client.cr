require "http/client"
require "json"
require "./merkle"
require "./block_header"
require "./spv"

module Harpy
  # Minimal client SDK for the Merkle anchoring API (MIC-81). Both genesis and
  # a recent canonical tip/checkpoint must be pinned out-of-band; proof data and
  # trust roots must not come from the same HTTP origin.
  class AnchorClient
    def initialize(
      @trusted_genesis_hash : String,
      @trusted_tip_hash : String,
      @base_url : String = "http://127.0.0.1:3000",
      @api_key : String? = nil,
    )
    end

    # Submit a record hash; returns the number of pending (un-mined) records.
    def submit(record_hash : String) : Int32
      resp = HTTP::Client.post("#{@base_url}/anchor", headers: auth_headers, body: {record_hash: record_hash}.to_json)
      raise "anchor submit failed: #{resp.status_code} #{resp.body}" unless resp.success?

      JSON.parse(resp.body)["pending"].as_i
    end

    # Fetch the inclusion proof for an anchored record and verify it locally.
    # Returns true iff the record is committed in the chain ending at the
    # caller-pinned trusted tip.
    def verify(record_hash : String) : Bool
      resp = HTTP::Client.get("#{@base_url}/anchor/#{record_hash}")
      return false unless resp.success?

      parsed = JSON.parse(resp.body)
      header = BlockHeader.from_json(parsed["header"].to_json)
      proof = Array(Merkle::ProofStep).from_json(parsed["merkle_proof"].to_json)
      block_index = parsed["block_index"].as_i
      headers_resp = HTTP::Client.get("#{@base_url}/headers?from=0")
      return false unless headers_resp.success?

      headers = Array(BlockHeader).from_json(headers_resp.body)
      trusted_tip_position = headers.index { |candidate| candidate.hash == @trusted_tip_hash }
      return false unless trusted_tip_position

      headers = headers[0..trusted_tip_position]
      target = headers.find { |candidate| candidate.index == block_index }
      return false unless target && target.hash == header.hash

      Spv.verify_anchor(
        record_hash,
        proof,
        headers,
        block_index,
        @trusted_genesis_hash,
        @trusted_tip_hash,
      )
    end

    private def auth_headers : HTTP::Headers
      headers = HTTP::Headers{"Content-Type" => "application/json"}
      if key = @api_key
        headers["Authorization"] = "Bearer #{key}"
      end
      headers
    end
  end
end
