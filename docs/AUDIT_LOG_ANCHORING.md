# Audit-log anchoring (MIC-82)

Harpy's integration endgame is a **verification layer**: commit a cryptographic
digest on-chain, keep the data off-chain. This walkthrough anchors audit-log
lines — the chain proves a line existed at a point in time without ever storing
the log.

See [STATE_MODEL.md](./STATE_MODEL.md) for the transaction model and
[THREAT_MODEL.md](./THREAT_MODEL.md) for the anchoring threat surface.

## How it works

1. **Hash off-chain.** The client SHA-256s each log line; only the 64-hex digest
   is submitted. The log text stays in the client's own store (file, S3, IPFS…).
2. **Batch + commit.** `POST /anchor` queues a digest. The next `POST /mine`
   builds a Merkle tree over the pending batch and seals its root into the new
   block's `anchor_root`, which is part of the block's proof-of-work hash
   ([block_header.cr](../src/harpy/block_header.cr)). Blocks with no pending
   anchors omit the field and hash exactly as before.
3. **Prove inclusion.** `GET /anchor/:record_hash` returns the sealing block
   **header** plus a Merkle proof. A light client verifies locally with
   `Harpy::Spv.verify_anchor` — no full node required.

Because `anchor_root` is inside the PoW preimage, a valid header with that root
represents real mining work; tampering the root invalidates the hash.

## Self-contained demo

```bash
crystal run examples/audit_log_anchoring.cr
```

Output ends with `DEMO OK`: it anchors four log lines, mines a sealing block,
verifies line 2's inclusion from the header + proof, and shows that a tampered
line fails verification. Source: [examples/audit_log_anchoring.cr](../examples/audit_log_anchoring.cr).

## Over HTTP

```bash
# 1. Submit record hashes (auth required when HARPY_API_KEY is set)
curl -X POST http://127.0.0.1:3000/anchor \
  -H "Content-Type: application/json" \
  -d "{\"record_hash\":\"$(printf 'log line one' | sha256sum | cut -d' ' -f1)\"}"

# 2. Mine a block that seals the batch (Ed25519 pubkey = coinbase payout)
curl -X POST http://127.0.0.1:3000/mine \
  -H "Content-Type: application/json" \
  -d '{"miner_pubkey":"<64-hex-ed25519-pubkey>"}'

# 3. Fetch the inclusion proof + sealing header
curl http://127.0.0.1:3000/anchor/<record_hash>
```

The response has `{record_hash, block_index, anchor_root, merkle_proof, header}`.

## Client SDK

[`Harpy::AnchorClient`](../src/harpy/anchor_client.cr) wraps submit + local
verification:

```crystal
client = Harpy::AnchorClient.new("http://127.0.0.1:3000")
client.submit(digest)          # queue a record hash
# ... after a block is mined ...
client.verify(digest)          # fetch proof + verify against the sealing header → Bool
```

`verify` fetches the proof and runs `Harpy::Spv.verify_anchor` client-side, so a
caller trusts the commitment without re-downloading the chain.

## Limitations (tutorial scope)

- The record→proof index is **in-memory**: the durable commitment is the on-chain
  `anchor_root`, but the mapping used to rebuild a proof is lost on restart and is
  not re-derived after a reorg that drops a sealing block. A production layer would
  persist anchored leaves (or recompute proofs from a stored batch).
- One anchor batch per block (the pending pool at mine time). High submission
  rates would want batching/interval controls.
