module Harpy
  module Economics
    BLOCK_REWARD      = 50_000_000_u64
    COINBASE_MATURITY =        100_u32
    MIN_TX_FEE        =      1_000_u64
    MAX_TXS_PER_BLOCK =        100_u32
    TX_VERSION        =          1_u32

    # Default genesis coinbase recipient (Ed25519 pubkey hex). Override with HARPY_GENESIS_PUBKEY.
    DEFAULT_GENESIS_PUBKEY = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"

    RETARGET_INTERVAL     = 10_i32
    TARGET_BLOCK_TIME_SEC = 60_i32
    MIN_DIFFICULTY        =  0_i32
    MAX_DIFFICULTY        =  8_i32

    def self.genesis_pubkey : String
      ENV["HARPY_GENESIS_PUBKEY"]? || DEFAULT_GENESIS_PUBKEY
    end
  end
end
