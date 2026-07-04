require "http/client"
require "json"
require "./merkle"
require "./block_header"
require "./spv"

module Harpy
  # Minimal client SDK for the Merkle anchoring API (MIC-81). Submit a record
  # hash, then fetch and *locally verify* its inclusion proof against the sealing
  # block header — the whole point of anchoring is that a light client can trust
  # the commitment without running a full node.
  class AnchorClient
    def initialize(@base_url : String = "http://127.0.0.1:3000", @api_key : String? = nil)
    end

    # Submit a record hash; returns the number of pending (un-mined) records.
    def submit(record_hash : String) : Int32
      resp = HTTP::Client.post("#{@base_url}/anchor", headers: auth_headers, body: {record_hash: record_hash}.to_json)
      raise "anchor submit failed: #{resp.status_code} #{resp.body}" unless resp.success?

      JSON.parse(resp.body)["pending"].as_i
    end

    # Fetch the inclusion proof for an anchored record and verify it locally.
    # Returns true iff the record is provably committed on-chain.
    def verify(record_hash : String) : Bool
      resp = HTTP::Client.get("#{@base_url}/anchor/#{record_hash}")
      return false unless resp.success?

      parsed = JSON.parse(resp.body)
      header = BlockHeader.from_json(parsed["header"].to_json)
      proof = Array(Merkle::ProofStep).from_json(parsed["merkle_proof"].to_json)
      Spv.verify_anchor(record_hash, proof, header)
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
