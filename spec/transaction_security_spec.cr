require "./spec_helper"

module Harpy::TransactionSecuritySpecHelpers
  def self.mature_chain_with_miner
    miner_key, _ = Harpy::SpecHelpers.generate_keypair
    miner_pubkey = Harpy::Crypto.pubkey_hex(miner_key.verify_key)
    chain = Harpy::SpecHelpers.build_chain((Harpy::Economics::COINBASE_MATURITY + 1).to_i32, miner_pubkey: miner_pubkey)
    {chain, miner_key, miner_pubkey}
  end
end

describe "transaction security" do
  it "rejects a double-spend in the mempool" do
    chain, miner_key, _ = Harpy::TransactionSecuritySpecHelpers.mature_chain_with_miner
    coinbase = chain.blocks.first.transactions.first.as(Harpy::CoinbaseTx)
    outpoint = Harpy::OutPoint.new(coinbase.txid, 0_u32)

    recipient_key, _ = Harpy::SpecHelpers.generate_keypair
    recipient = Harpy::Crypto.pubkey_hex(recipient_key.verify_key)

    tx1 = Harpy::SpecHelpers.build_spend_tx(
      outpoint,
      Harpy::Economics::BLOCK_REWARD,
      miner_key,
      recipient,
      1_000_000_u64,
    )
    tx2 = Harpy::SpecHelpers.build_spend_tx(
      outpoint,
      Harpy::Economics::BLOCK_REWARD,
      miner_key,
      recipient,
      2_000_000_u64,
    )

    chain.mempool.add(tx1, chain.utxo_set, chain.height.to_u32).should eq(Harpy::Mempool::AddResult::Accepted)
    chain.mempool.add(tx2, chain.utxo_set, chain.height.to_u32).should eq(Harpy::Mempool::AddResult::Conflict)
  end

  it "rejects spending with insufficient balance" do
    chain, miner_key, _ = Harpy::TransactionSecuritySpecHelpers.mature_chain_with_miner
    coinbase = chain.blocks.first.transactions.first.as(Harpy::CoinbaseTx)
    outpoint = Harpy::OutPoint.new(coinbase.txid, 0_u32)

    recipient_key, _ = Harpy::SpecHelpers.generate_keypair
    recipient = Harpy::Crypto.pubkey_hex(recipient_key.verify_key)

    tx = Harpy::Transaction.new(
      inputs: [Harpy::TxInput.new(outpoint)],
      outputs: [Harpy::TxOutput.new(Harpy::Economics::BLOCK_REWARD, recipient)],
    ).sign_all(miner_key)

    chain.mempool.add(tx, chain.utxo_set, chain.height.to_u32).should eq(Harpy::Mempool::AddResult::Invalid)
  end

  it "rejects a transaction with a bad signature" do
    chain, _, _ = Harpy::TransactionSecuritySpecHelpers.mature_chain_with_miner
    other_key, _ = Harpy::SpecHelpers.generate_keypair
    coinbase = chain.blocks.first.transactions.first.as(Harpy::CoinbaseTx)
    outpoint = Harpy::OutPoint.new(coinbase.txid, 0_u32)

    recipient_key, _ = Harpy::SpecHelpers.generate_keypair
    recipient = Harpy::Crypto.pubkey_hex(recipient_key.verify_key)

    tx = Harpy::SpecHelpers.build_spend_tx(
      outpoint,
      Harpy::Economics::BLOCK_REWARD,
      other_key,
      recipient,
      1_000_000_u64,
    )

    chain.mempool.add(tx, chain.utxo_set, chain.height.to_u32).should eq(Harpy::Mempool::AddResult::Invalid)
  end

  it "rejects spending immature coinbase outputs" do
    chain = Harpy::SpecHelpers.build_chain(1)
    signing_key, _ = Harpy::SpecHelpers.generate_keypair
    genesis_coinbase = chain.blocks.first.transactions.first.as(Harpy::CoinbaseTx)
    outpoint = Harpy::OutPoint.new(genesis_coinbase.txid, 0_u32)

    recipient_key, _ = Harpy::SpecHelpers.generate_keypair
    recipient = Harpy::Crypto.pubkey_hex(recipient_key.verify_key)

    tx = Harpy::SpecHelpers.build_spend_tx(
      outpoint,
      Harpy::Economics::BLOCK_REWARD,
      signing_key,
      recipient,
      1_000_000_u64,
    )

    chain.utxo_set.spendable?(outpoint, chain.height.to_u32).should be_false
    chain.mempool.add(tx, chain.utxo_set, chain.height.to_u32).should eq(Harpy::Mempool::AddResult::Invalid)
  end

  it "allows spending mature coinbase outputs" do
    chain, miner_key, _ = Harpy::TransactionSecuritySpecHelpers.mature_chain_with_miner
    coinbase = chain.blocks.first.transactions.first.as(Harpy::CoinbaseTx)
    outpoint = Harpy::OutPoint.new(coinbase.txid, 0_u32)
    chain.utxo_set.spendable?(outpoint, chain.height.to_u32).should be_true

    recipient_key, _ = Harpy::SpecHelpers.generate_keypair
    recipient = Harpy::Crypto.pubkey_hex(recipient_key.verify_key)

    tx = Harpy::SpecHelpers.build_spend_tx(
      outpoint,
      Harpy::Economics::BLOCK_REWARD,
      miner_key,
      recipient,
      1_000_000_u64,
    )

    chain.mempool.add(tx, chain.utxo_set, chain.height.to_u32).should eq(Harpy::Mempool::AddResult::Accepted)
  end

  it "rejects zero-fee transactions" do
    chain, miner_key, _ = Harpy::TransactionSecuritySpecHelpers.mature_chain_with_miner
    coinbase = chain.blocks.first.transactions.first.as(Harpy::CoinbaseTx)
    outpoint = Harpy::OutPoint.new(coinbase.txid, 0_u32)

    recipient_key, _ = Harpy::SpecHelpers.generate_keypair
    recipient = Harpy::Crypto.pubkey_hex(recipient_key.verify_key)
    # Spend entire input with no fee left for miner
    send_amount = Harpy::Economics::BLOCK_REWARD

    tx = Harpy::Transaction.new(
      inputs: [Harpy::TxInput.new(outpoint)],
      outputs: [Harpy::TxOutput.new(send_amount, recipient)],
    ).sign_all(miner_key)

    chain.mempool.add(tx, chain.utxo_set, chain.height.to_u32).should eq(Harpy::Mempool::AddResult::Invalid)
  end

  it "accepts a transaction paying exactly MIN_TX_FEE" do
    chain, miner_key, _ = Harpy::TransactionSecuritySpecHelpers.mature_chain_with_miner
    coinbase = chain.blocks.first.transactions.first.as(Harpy::CoinbaseTx)
    outpoint = Harpy::OutPoint.new(coinbase.txid, 0_u32)

    recipient_key, _ = Harpy::SpecHelpers.generate_keypair
    recipient = Harpy::Crypto.pubkey_hex(recipient_key.verify_key)
    fee = Harpy::Economics::MIN_TX_FEE
    send_amount = Harpy::Economics::BLOCK_REWARD - fee

    tx = Harpy::Transaction.new(
      inputs: [Harpy::TxInput.new(outpoint)],
      outputs: [Harpy::TxOutput.new(send_amount, recipient)],
    ).sign_all(miner_key)

    chain.mempool.add(tx, chain.utxo_set, chain.height.to_u32).should eq(Harpy::Mempool::AddResult::Accepted)
  end

  it "rejects a transaction paying below MIN_TX_FEE" do
    chain, miner_key, _ = Harpy::TransactionSecuritySpecHelpers.mature_chain_with_miner
    coinbase = chain.blocks.first.transactions.first.as(Harpy::CoinbaseTx)
    outpoint = Harpy::OutPoint.new(coinbase.txid, 0_u32)

    recipient_key, _ = Harpy::SpecHelpers.generate_keypair
    recipient = Harpy::Crypto.pubkey_hex(recipient_key.verify_key)
    fee = Harpy::Economics::MIN_TX_FEE - 1
    send_amount = Harpy::Economics::BLOCK_REWARD - fee

    tx = Harpy::Transaction.new(
      inputs: [Harpy::TxInput.new(outpoint)],
      outputs: [Harpy::TxOutput.new(send_amount, recipient)],
    ).sign_all(miner_key)

    chain.mempool.add(tx, chain.utxo_set, chain.height.to_u32).should eq(Harpy::Mempool::AddResult::Invalid)
  end

  it "rejects a transaction output with a malformed public key" do
    chain, miner_key, _ = Harpy::TransactionSecuritySpecHelpers.mature_chain_with_miner
    coinbase = chain.blocks.first.transactions.first.as(Harpy::CoinbaseTx)
    outpoint = Harpy::OutPoint.new(coinbase.txid, 0_u32)
    tx = Harpy::Transaction.new(
      inputs: [Harpy::TxInput.new(outpoint)],
      outputs: [Harpy::TxOutput.new(Harpy::Economics::BLOCK_REWARD - Harpy::Economics::MIN_TX_FEE, "z" * 64)],
    ).sign_all(miner_key)

    chain.mempool.add(tx, chain.utxo_set, chain.height.to_u32).should eq(Harpy::Mempool::AddResult::Invalid)
  end
end
