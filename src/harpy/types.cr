module Harpy
  VERSION = "0.1.0"

  alias BlockType = NamedTuple(
    index: Int32,
    timestamp: String,
    data: String,
    hash: String,
    prev_hash: String,
    difficulty: Int32,
    nonce: String,
  )
end
