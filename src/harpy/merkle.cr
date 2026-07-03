require "digest/sha256"

module Harpy
  module Merkle
    extend self

    def root(txids : Array(String)) : String
      return Digest::SHA256.hexdigest("") if txids.empty?

      layer = txids.map { |id| hex_to_bytes(id) }
      while layer.size > 1
        layer = pair_layer(layer)
      end

      layer.first.hexstring
    end

    private def pair_layer(layer : Array(Bytes)) : Array(Bytes)
      padded = layer.dup
      padded << padded.last if padded.size.odd?

      pairs = [] of Bytes
      padded.each_slice(2) do |(left, right)|
        pairs << Digest::SHA256.digest(left + right)
      end
      pairs
    end

    private def hex_to_bytes(hex : String) : Bytes
      hex.hexbytes
    end
  end
end
