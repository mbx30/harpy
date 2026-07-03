require "http/request"
require "crypto/subtle"

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

    # Whether to trust the `X-Forwarded-For` header for client identification
    # (rate limiting). Off by default: when the node is reached directly, that
    # header is fully attacker-controlled, so honoring it lets a client forge a
    # fresh identity per request — bypassing the per-IP limit and growing the
    # bucket map without bound. Enable only when a trusted reverse proxy that
    # sets/overwrites `X-Forwarded-For` sits in front of the node.
    def trust_proxy? : Bool
      case ENV["HARPY_TRUST_PROXY"]?.try(&.downcase)
      when "1", "true", "yes", "on"
        true
      else
        false
      end
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
        return true if secure_equal?(token, key)
      end

      if header_key = request.headers["X-API-Key"]?
        return true if secure_equal?(header_key, key)
      end

      false
    end

    # Constant-time string comparison for the write-auth secret. A plain `==`
    # short-circuits on the first differing byte, leaking via response timing how
    # many leading bytes of a guess were correct — enough to recover the key
    # byte-by-byte against an exposed node. `Crypto::Subtle.constant_time_compare`
    # is length-safe and does not early-exit.
    private def secure_equal?(a : String, b : String) : Bool
      Crypto::Subtle.constant_time_compare(a, b)
    end
  end
end
