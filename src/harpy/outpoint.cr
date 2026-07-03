require "json"

module Harpy
  struct OutPoint
    include JSON::Serializable

    getter txid : String
    getter vout : UInt32

    def initialize(@txid : String, @vout : UInt32)
    end

    def ==(other : OutPoint) : Bool
      @txid == other.txid && @vout == other.vout
    end

    def hash(hasher)
      hasher = hasher.dup
      @txid.hash(hasher)
      @vout.hash(hasher)
      hasher
    end
  end
end
