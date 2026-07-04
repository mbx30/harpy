require "ed25519"
require "digest/sha256"

module Harpy
  module Crypto
    extend self

    SIG_ALGORITHM_ED25519 = "ed25519"

    # Crypto-agile address format (MIC-66). An address self-describes its version
    # and signature algorithm so new algorithms (e.g. post-quantum ML-DSA) can be
    # added without a breaking format change — old and new addresses coexist.
    #
    # Layout (hex after the "harpy1" prefix): version(1B) ‖ algo_id(1B) ‖
    # pubkey(32B) ‖ checksum(4B), where checksum = SHA256(version‖algo_id‖pubkey)[0,4].
    ADDRESS_HRP     = "harpy1"
    ADDRESS_VERSION = 1_u8

    # algorithm identifier ↔ byte, the crypto-agility hinge point.
    ADDRESS_ALGO_IDS = {SIG_ALGORITHM_ED25519 => 1_u8}

    def generate_keypair : {Ed25519::SigningKey, Ed25519::VerifyKey}
      signing_key = Ed25519::SigningKey.new
      {signing_key, signing_key.verify_key}
    end

    def sign(message : Bytes, signing_key : Ed25519::SigningKey) : String
      signing_key.sign(message).hexstring
    end

    def verify(message : Bytes, signature_hex : String, pubkey_hex : String, algorithm : String = SIG_ALGORITHM_ED25519) : Bool
      return false unless algorithm == SIG_ALGORITHM_ED25519
      return false unless signature_hex.size == 128
      return false unless pubkey_hex.size == 64

      begin
        signature = signature_hex.hexbytes
        pubkey = pubkey_hex.hexbytes
        verify_key = Ed25519::VerifyKey.new(pubkey)
        verify_key.verify(signature, message)
      rescue
        false
      end
    end

    def pubkey_hex(verify_key : Ed25519::VerifyKey) : String
      verify_key.key_bytes.hexstring
    end

    # Encode a public key as a versioned, algorithm-tagged, checksummed address.
    def address_for(pubkey_hex : String, algorithm : String = SIG_ALGORITHM_ED25519) : String
      algo_id = ADDRESS_ALGO_IDS[algorithm]?
      raise ArgumentError.new("unknown signature algorithm: #{algorithm}") unless algo_id
      raise ArgumentError.new("pubkey must be 64-char hex") unless valid_hex?(pubkey_hex, 64)

      payload = Bytes[ADDRESS_VERSION, algo_id] + pubkey_hex.hexbytes
      checksum = Digest::SHA256.digest(payload)[0, 4]
      ADDRESS_HRP + (payload + checksum).hexstring
    end

    # Decode an address back to its pubkey hex, or nil if malformed / bad checksum
    # / unknown version. Use `address_algorithm` to recover the signature scheme.
    def pubkey_from_address(address : String) : String?
      decode_address(address).try &.[:pubkey]
    end

    def address_algorithm(address : String) : String?
      decode_address(address).try &.[:algorithm]
    end

    def address_valid?(address : String) : Bool
      !decode_address(address).nil?
    end

    private def decode_address(address : String) : NamedTuple(pubkey: String, algorithm: String)?
      return nil unless address.starts_with?(ADDRESS_HRP)

      hex = address[ADDRESS_HRP.size..]
      return nil unless valid_hex?(hex, 76) # 38 bytes: 1+1+32+4

      bytes = hex.hexbytes
      payload = bytes[0, 34]
      checksum = bytes[34, 4]
      return nil unless Digest::SHA256.digest(payload)[0, 4] == checksum
      return nil unless payload[0] == ADDRESS_VERSION

      algorithm = ADDRESS_ALGO_IDS.key_for?(payload[1])
      return nil unless algorithm

      {pubkey: payload[2, 32].hexstring, algorithm: algorithm}
    end

    private def valid_hex?(value : String, size : Int32) : Bool
      value.size == size && value.each_char.all? { |c| c.ascii_number? || ('a'..'f').includes?(c) }
    end
  end
end
