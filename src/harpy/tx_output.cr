require "json"

module Harpy
  struct TxOutput
    include JSON::Serializable

    getter amount : UInt64
    getter pubkey : String

    def initialize(@amount : UInt64, @pubkey : String)
    end
  end
end
