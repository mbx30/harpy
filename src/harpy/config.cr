require "http/request"
require "crypto/subtle"

class Harpy::ConfigError < Exception
end

module Harpy
  module Config
    extend self

    # Maximum JSON request body for POST /new-block (64 KiB).
    MAX_REQUEST_BODY_BYTES = 64 * 1024

    # Maximum serialized block transactions JSON (32 KiB).
    MAX_BLOCK_TRANSACTIONS_BYTES = 32 * 1024

    DEFAULT_RATE_LIMIT_MAX      =  2
    DEFAULT_RATE_LIMIT_WINDOW_S = 10

    DEFAULT_P2P_PORT      = 9333
    MAX_P2P_MESSAGE_BYTES = 512 * 1024

    # Bind to loopback by default; require an explicit opt-in to expose on the LAN/public interfaces.
    DEFAULT_BIND_HOST = "127.0.0.1"
    DEFAULT_HTTP_PORT = 3000

    DEFAULT_GENESIS_TIMESTAMP = "2026-07-20 00:00:00 UTC"

    def max_request_body_bytes : Int32
      MAX_REQUEST_BODY_BYTES
    end

    def max_block_transactions_bytes : Int32
      MAX_BLOCK_TRANSACTIONS_BYTES
    end

    def genesis_difficulty : Int32
      if value = ENV["HARPY_DIFFICULTY"]?
        if parsed = value.to_i?
          return parsed if Difficulty.valid_difficulty?(parsed)
        end
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
      value = ENV["HARPY_API_KEY"]?
      return nil unless value
      raise ConfigError.new("HARPY_API_KEY must not be empty") if value.strip.empty?

      value
    end

    def genesis_pubkey : String
      value = ENV["HARPY_GENESIS_PUBKEY"]? || Economics::DEFAULT_GENESIS_PUBKEY
      unless Crypto.valid_pubkey_hex?(value)
        raise ConfigError.new("HARPY_GENESIS_PUBKEY must be a 64-char lowercase hex Ed25519 public key")
      end

      value
    end

    def genesis_timestamp(now : Time = Time.utc) : String
      value = ENV["HARPY_GENESIS_TIMESTAMP"]? || DEFAULT_GENESIS_TIMESTAMP
      unless Difficulty.parse_timestamp(value)
        raise ConfigError.new("HARPY_GENESIS_TIMESTAMP must match YYYY-MM-DD HH:MM:SS UTC")
      end
      unless Difficulty.valid_genesis_timestamp?(value, now)
        raise ConfigError.new("HARPY_GENESIS_TIMESTAMP must not be more than two hours in the future")
      end

      value
    end

    def bind_host : String
      if value = ENV["HARPY_BIND_HOST"]?
        return value unless value.empty?
      end

      DEFAULT_BIND_HOST
    end

    def validate!(key : String? = api_key) : Nil
      raise ConfigError.new("HARPY_API_KEY must not be empty") if key.try(&.strip.empty?)

      if key.nil? && !loopback_host?(bind_host)
        raise ConfigError.new("HARPY_API_KEY is required when HARPY_BIND_HOST is not loopback")
      end
    end

    def http_port : Int32
      if value = ENV["HARPY_HTTP_PORT"]? || ENV["PORT"]?
        parsed = value.to_i
        return parsed if parsed > 0
      end

      DEFAULT_HTTP_PORT
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

    def p2p_enabled? : Bool
      ENV["HARPY_P2P_DISABLE"]? != "1"
    end

    def p2p_port : Int32
      if value = ENV["HARPY_P2P_PORT"]?
        parsed = value.to_i
        return parsed if parsed > 0
      end

      DEFAULT_P2P_PORT
    end

    def p2p_peers : Array(String)
      raw = ENV["HARPY_P2P_PEERS"]?
      return [] of String unless raw

      raw.split(',').map(&.strip).reject(&.empty?)
    end

    def anchor_peers : Array(String)
      raw = ENV["HARPY_ANCHOR_PEERS"]?
      return [] of String unless raw

      raw.split(',').map(&.strip).reject(&.empty?)
    end

    def max_p2p_message_bytes : Int32
      MAX_P2P_MESSAGE_BYTES
    end

    def write_authorized?(request : HTTP::Request, key : String? = api_key) : Bool
      return true unless key

      return false if key.empty?

      if auth = request.headers["Authorization"]?
        if match = auth.match(/\ABearer ([^\s]+)\z/)
          return true if secure_equal?(match[1], key)
        end
      end

      if header_key = request.headers["X-API-Key"]?
        unless header_key.empty?
          return true if secure_equal?(header_key, key)
        end
      end

      false
    end

    # Constant-time string comparison for the write-auth secret. A plain `==`
    # short-circuits on the first differing byte, leaking via response timing how
    # many leading bytes of a guess were correct — enough to recover the key
    # byte-by-byte against an exposed node. `Crypto::Subtle.constant_time_compare`
    # is length-safe and does not early-exit.
    private def secure_equal?(a : String, b : String) : Bool
      ::Crypto::Subtle.constant_time_compare(a, b)
    end

    private def loopback_host?(host : String) : Bool
      host == "127.0.0.1" || host == "::1" || host == "localhost"
    end
  end
end
