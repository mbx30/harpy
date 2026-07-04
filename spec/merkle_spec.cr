require "./spec_helper"

private def txid(seed : String) : String
  Digest::SHA256.hexdigest(seed)
end

describe Harpy::Merkle do
  describe ".proof / .verify_proof" do
    it "verifies an inclusion proof for every leaf across tree sizes" do
      (1..9).each do |n|
        txids = (0...n).map { |i| txid("tx-#{n}-#{i}") }
        root = Harpy::Merkle.root(txids)

        txids.each_with_index do |leaf, index|
          proof = Harpy::Merkle.proof(txids, index)
          Harpy::Merkle.verify_proof(leaf, proof, root).should be_true
        end
      end
    end

    it "handles a single-leaf tree with an empty proof" do
      leaf = txid("only")
      root = Harpy::Merkle.root([leaf])

      proof = Harpy::Merkle.proof([leaf], 0)
      proof.should be_empty
      root.should eq(leaf)
      Harpy::Merkle.verify_proof(leaf, proof, root).should be_true
    end

    it "rejects a proof against the wrong root" do
      txids = (0...5).map { |i| txid("a-#{i}") }
      proof = Harpy::Merkle.proof(txids, 2)

      Harpy::Merkle.verify_proof(txids[2], proof, txid("not-the-root")).should be_false
    end

    it "rejects a proof for a tampered leaf" do
      txids = (0...5).map { |i| txid("b-#{i}") }
      root = Harpy::Merkle.root(txids)
      proof = Harpy::Merkle.proof(txids, 3)

      Harpy::Merkle.verify_proof(txid("tampered"), proof, root).should be_false
    end

    it "rejects a proof with a corrupted sibling" do
      txids = (0...6).map { |i| txid("c-#{i}") }
      root = Harpy::Merkle.root(txids)
      proof = Harpy::Merkle.proof(txids, 1)
      corrupted = proof.dup
      corrupted[0] = {hash: txid("evil"), left: proof[0][:left]}

      Harpy::Merkle.verify_proof(txids[1], corrupted, root).should be_false
    end

    it "raises for an out-of-range index" do
      txids = [txid("x"), txid("y")]
      expect_raises(ArgumentError) { Harpy::Merkle.proof(txids, 5) }
    end
  end
end
