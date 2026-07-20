# L2 scaling trade-offs for integration throughput (MIC-91)

What happens if integration demand outgrows what Harpy's L1 can anchor? This
note ranks the levers. Sources: the Layer-2 survey
[arXiv:2107.10881](https://arxiv.org/abs/2107.10881), the L1-vs-L2 comparison
[arXiv:2406.13855](https://arxiv.org/abs/2406.13855), and a ZK-rollup PoC
[arXiv:2506.00500](https://arxiv.org/abs/2506.00500) (~98 TPS, ~2.5 s median
latency on commodity hardware).

## Lever 0: batching — already shipped, and it goes very far

Anchoring is hash-on-chain, data off-chain
([AUDIT_LOG_ANCHORING.md](./AUDIT_LOG_ANCHORING.md)): one Merkle root commits
an arbitrary number of records (OpenTimestamps model). Throughput in
records/sec is `batch_size / block_interval` — with a 60 s target interval,
batching 10,000 records per anchor root is ~166 records/s using **one field in
one block**, and the per-record proof stays `O(log n)`. Record throughput is
effectively unbounded; what is bounded is **anchor latency** (one block
interval to seal, plus confirmation depth to trust,
[CONFIRMATION_DEPTH.md](./CONFIRMATION_DEPTH.md)) and **on-chain state
transitions** (real txs, ~max block payload / interval).

So: scaling *record* volume never requires an L2. Only two demands do —
lower time-to-finality per record, or more on-chain transactions.

## Lever 1: optimistic rollup

Execution moves off-chain; batches post to L1 with a fraud-proof challenge
window. Cheap prover, mature pattern — but withdrawals/finality inherit the
challenge window (days, not seconds), which is the *opposite* of what an
anchoring latency problem needs, and it requires live watchers
(same honest-minority liveness assumption discussed in
[LIGHT_CLIENT_BRIDGES.md](./LIGHT_CLIENT_BRIDGES.md) pattern 2).

## Lever 2: ZK rollup

Validity proofs replace the challenge window: fast finality at the cost of
proving overhead and circuit complexity. The PoC numbers
([arXiv:2506.00500](https://arxiv.org/abs/2506.00500)) show ~98 TPS / ~2.5 s
latency is achievable, but the engineering weight (prover infrastructure,
circuit audits) is an order of magnitude beyond Harpy's educational scope.

## Trade-off summary

| Lever | Throughput gain | Finality latency | New trust/infra cost |
|---|---|---|---|
| Batched anchoring (now) | ~unbounded for records | 1 block + k confirmations | none — already trust-minimal |
| Optimistic rollup | high for state txs | + challenge window (days) | watchers, sequencer, fraud proofs |
| ZK rollup | high for state txs | seconds after proof | prover infra, circuit audits |

## Position

- Batching under one Merkle root is the primary and probably permanent
  high-throughput lever; revisit only if a real integration needs sub-interval
  finality or heavy on-chain state.
- If that day comes, prefer ZK over optimistic for anchoring-shaped workloads
  (finality is the product; a challenge window poisons it), and reuse the
  header/SPV surface as the settlement interface — same reasoning as the
  bridge ranking in [LIGHT_CLIENT_BRIDGES.md](./LIGHT_CLIENT_BRIDGES.md).
- Interim cheap trick if block space ever tightens: shorten the target block
  interval at a retarget boundary ([difficulty.cr](../src/harpy/difficulty.cr))
  before reaching for any L2 — recompute confirmation depth accordingly.
