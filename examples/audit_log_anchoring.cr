# Audit-log anchoring demo (MIC-82).
#
# Demonstrates the "hash-on-chain, data off-chain" pattern: hash each audit-log
# line off-chain, commit the batch's Merkle root on-chain in a block's
# `anchor_root`, then prove any single line was anchored using only the block
# header + a Merkle proof — the log itself never touches the chain.
#
# Run: crystal run examples/audit_log_anchoring.cr

require "../src/harpy/*"

log_lines = [
  "2026-07-04T09:00:00Z user=alice action=login ip=10.0.0.5",
  "2026-07-04T09:01:12Z user=alice action=export report=Q2",
  "2026-07-04T09:03:47Z user=bob action=login ip=10.0.0.9",
  "2026-07-04T09:04:10Z user=bob action=delete record=1234",
]

puts "== Harpy audit-log anchoring demo =="
puts

Harpy::Anchor.reset!
chain = Harpy::Chain.new([Harpy::Miner.mine(Harpy::Block.genesis(difficulty: 0))])
_, verify_key = Harpy::Crypto.generate_keypair
miner_pubkey = Harpy::Crypto.pubkey_hex(verify_key)

# 1. Hash each log line off-chain and submit only the digest.
digests = log_lines.map { |line| Digest::SHA256.hexdigest(line) }
digests.each_with_index { |d, i| Harpy::Anchor.submit(d); puts "submitted line #{i}: #{d}" }
puts

# 2. Mine a block that seals the pending batch into anchor_root (part of the PoW hash).
batch = Harpy::Anchor.take_pending_batch!
block = Harpy::Miner.mine_from_mempool(chain, miner_pubkey, anchor_root: batch.not_nil!.root)
raise "block rejected" unless chain.append!(block)
Harpy::Anchor.seal!(block.hash, batch.not_nil!.leaves)
puts "mined block ##{block.index}"
puts "  block hash : #{block.hash}"
puts "  anchor_root: #{block.anchor_root}"
puts

# 3. Later, prove line 2 was anchored using trusted headers + a Merkle proof.
target = log_lines[2]
target_digest = Digest::SHA256.hexdigest(target)
info = Harpy::Anchor.proof_for(target_digest).not_nil!
header = chain.block_by_hash(info.block_hash).not_nil!.header
headers = chain.blocks[0..sealing.index].map(&.header)
ok = Harpy::Spv.verify_anchor(target_digest, info.proof, headers, chain.genesis_hash)
puts "verify anchored line 2 => #{ok}"

# 4. A tampered log line no longer verifies against the on-chain commitment.
tampered_digest = Digest::SHA256.hexdigest(target + " (edited)")
tampered_ok = Harpy::Spv.verify_anchor(tampered_digest, info.proof, headers, chain.genesis_hash)
puts "verify tampered line   => #{tampered_ok}  (expected false)"

puts
if ok && !tampered_ok
  puts "DEMO OK"
else
  puts "DEMO FAILED"
  exit 1
end
