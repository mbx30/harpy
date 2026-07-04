require "./spec_helper"

describe "Harpy::Crypto address format (MIC-66)" do
  it "round-trips a pubkey through an address" do
    _, verify_key = Harpy::Crypto.generate_keypair
    pubkey = Harpy::Crypto.pubkey_hex(verify_key)

    address = Harpy::Crypto.address_for(pubkey)
    address.should start_with("harpy1")
    Harpy::Crypto.pubkey_from_address(address).should eq(pubkey)
    Harpy::Crypto.address_algorithm(address).should eq(Harpy::Crypto::SIG_ALGORITHM_ED25519)
    Harpy::Crypto.address_valid?(address).should be_true
  end

  it "rejects an address with a corrupted checksum" do
    _, verify_key = Harpy::Crypto.generate_keypair
    address = Harpy::Crypto.address_for(Harpy::Crypto.pubkey_hex(verify_key))
    # Flip the last hex char (part of the checksum).
    corrupted = address[0...-1] + (address[-1] == 'a' ? 'b' : 'a')

    Harpy::Crypto.pubkey_from_address(corrupted).should be_nil
    Harpy::Crypto.address_valid?(corrupted).should be_false
  end

  it "rejects a foreign prefix and wrong length" do
    Harpy::Crypto.pubkey_from_address("btc1abcdef").should be_nil
    Harpy::Crypto.pubkey_from_address("harpy1dead").should be_nil
  end

  it "raises for an unknown signature algorithm" do
    _, verify_key = Harpy::Crypto.generate_keypair
    pubkey = Harpy::Crypto.pubkey_hex(verify_key)

    expect_raises(ArgumentError) { Harpy::Crypto.address_for(pubkey, "dilithium") }
  end

  it "raises for a malformed pubkey" do
    expect_raises(ArgumentError) { Harpy::Crypto.address_for("tooshort") }
  end
end
