require "http/request"

module Harpy
  module Config
    extend self

    # Maximum JSON request body for POST /new-block (64 KiB).
    MAX_REQUEST_BODY_BYTES = 64 * 1024

    # Maximum bytes stored in block.data (32 KiB). Must be ≤ MAX_REQUEST_BODY_BYTES.
    MAX_BLOCK_DATA_BYTES = 32 * 1024

    DEFAULT_RATE_LIMIT_MAX      =  2
    DEFAULT_RATE_LIMIT_WINDOW_S = 10

    # Bind to loopback by default; require an explicit opt-in to expose on the LAN/public interfaces.
    DEFAULT_BIND_HOST = "127.0.0.1"

    def max_request_body_bytes : Int32
      MAX_REQUEST_BODY_BYTES
    end

    def max_block_data_bytes : Int32
      MAX_BLOCK_DATA_BYTES
    end

    def genesis_difficulty : Int32
      if value = ENV["HARPY_DIFFICULTY"]?
        parsed = value.to_i
        return parsed if parsed >= 0
      end

      Block::DEFAULT_DIFFICULTY
    end

    def storage_path : String
      value = ENV["HARPY_DATA_DIR"]?
      return Storage::DEFAULT_PATH unless value

      return value if value.ends_with?(".json")

      File.join(value, "chain.json")
    end

    def api_key : String?
      ENV["HARPY_API_KEY"]?
    end

    def bind_host : String
      if value = ENV["HARPY_BIND_HOST"]?
        return value unless value.empty?
      end

      DEFAULT_BIND_HOST
    end

    def rate_limit_max : Int32
      if value = ENV["HARPY_RATE_LIMIT"]?
        parsed = value.to_i
        return parsed if parsed > 0
      end

      DEFAULT_RATE_LIMIT_MAX
    end

    def rate_limit_window_seconds : Int32
      if value = ENV["HARPY_RATE_LIMIT_WINDOW"]?
        parsed = value.to_i
        return parsed if parsed > 0
      end

      DEFAULT_RATE_LIMIT_WINDOW_S
    end

    def write_authorized?(request : HTTP::Request, key : String? = api_key) : Bool
      return true unless key

      if auth = request.headers["Authorization"]?
        token = auth.sub(/^Bearer\s+/i, "")
        return true if token == key
      end

      if header_key = request.headers["X-API-Key"]?
        return true if header_key == key
      end

      false
    end
  end
end
