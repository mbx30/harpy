require "ed25519"

module Harpy
  module Crypto
    extend self

    SIG_ALGORITHM_ED25519 = "ed25519"

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
  end
end
