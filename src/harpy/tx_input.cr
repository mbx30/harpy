require "json"

module Harpy
  struct TxInput
    include JSON::Serializable

    getter prev_out : OutPoint
    getter sig_algorithm : String
    getter signature : String

    def initialize(
      @prev_out : OutPoint,
      @signature : String = "",
      @sig_algorithm : String = Crypto::SIG_ALGORITHM_ED25519,
    )
    end

    def signing_view : Hash(String, JSON::Any)
      {
        "prev_out" => JSON.parse(@prev_out.to_json),
      }
    end
  end
end
