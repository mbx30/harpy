require "digest/sha256"
require "json"

module Harpy
  struct CoinbaseTx
    include JSON::Serializable

    getter version : UInt32
    getter outputs : Array(TxOutput)
    getter height : UInt32

    def initialize(
      @version : UInt32 = Economics::TX_VERSION,
      @outputs : Array(TxOutput) = [] of TxOutput,
      @height : UInt32 = 0,
    )
    end

    def canonical_body : String
      JSON.build do |json|
        json.object do
          json.field "height", @height
          json.field "outputs", @outputs
          json.field "version", @version
        end
      end
    end

    def txid : String
      Digest::SHA256.hexdigest(canonical_body)
    end

    def coinbase? : Bool
      true
    end
  end
end
