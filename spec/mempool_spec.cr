require "./spec_helper"

describe Harpy::Mempool do
  it "skips oversize leading txs so mining can still select fitting ones" do
    previous = Harpy::SpecHelpers.mined_genesis(difficulty: 0)
    _, verify_key = Harpy::SpecHelpers.generate_keypair
    miner_pubkey = Harpy::Crypto.pubkey_hex(verify_key)
    utxo_set = Harpy::UtxoSet.new

    huge_outputs = Array.new(500) { Harpy::TxOutput.new(1_u64, miner_pubkey) }
    huge = Harpy::Transaction.new(
      inputs: [Harpy::TxInput.new(Harpy::OutPoint.new("a" * 64, 0_u32))],
      outputs: huge_outputs,
    )
    small = Harpy::Transaction.new(
      inputs: [Harpy::TxInput.new(Harpy::OutPoint.new("b" * 64, 0_u32))],
      outputs: [Harpy::TxOutput.new(1_u64, miner_pubkey)],
    )

    mempool = Harpy::Mempool.new([huge, small])
    selected = mempool.select_for_block(previous, miner_pubkey, utxo_set, 0)

    selected.should eq([small])
    candidate = Harpy::Miner.build_block_with_fees(previous, selected, miner_pubkey, 0, utxo_set)
    candidate.transactions_within_limit?.should be_true
  end

  it "returns an empty selection when even a coinbase-only block is within limits" do
    previous = Harpy::SpecHelpers.mined_genesis(difficulty: 0)
    _, verify_key = Harpy::SpecHelpers.generate_keypair
    miner_pubkey = Harpy::Crypto.pubkey_hex(verify_key)

    mempool = Harpy::Mempool.new
    selected = mempool.select_for_block(previous, miner_pubkey, Harpy::UtxoSet.new, 0)

    selected.should be_empty
    coinbase_only = Harpy::Miner.build_block_with_fees(previous, selected, miner_pubkey, 0, Harpy::UtxoSet.new)
    coinbase_only.transactions_within_limit?.should be_true
  end
end
