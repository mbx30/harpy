# NIPoPoW and superlight client evaluation (MIC-93)

Harpy ships a basic SPV client (MIC-86): sync all headers between a pinned
genesis and an independently obtained trusted tip/checkpoint, verify PoW, then
verify Merkle inclusion. Cost is linear in chain length — fine for a tutorial
chain, and the question here is what lies beyond if sync cost ever matters.
Evaluated designs: NIPoPoWs / lazy blockchains
([arXiv:2203.15968](https://arxiv.org/abs/2203.15968)), LightSync
([arXiv:2112.03092](https://arxiv.org/abs/2112.03092)), committee-based light
clients ([arXiv:2410.03347](https://arxiv.org/abs/2410.03347)), and
unconditionally-safe light clients
([arXiv:2405.01459](https://arxiv.org/abs/2405.01459)).

Depends on the block-header format (MIC-80) — every option below is a
different way of consuming the same header chain.

## Options

1. **Full SPV (shipped).** `O(n)` headers. At Harpy scale (a 60 s interval is
   ~526k headers/year; compact fixed-field headers) a year of chain is a few
   tens of MB — genuinely fine.
2. **NIPoPoWs (superblock sampling).** Blocks whose hash overshoots the target
   ("μ-superblocks") form a logarithmic skeleton proving cumulative work;
   sync drops to `O(polylog n)`. Requires an **interlink** structure in the
   header committing to recent superblocks at each level — i.e., a
   consensus-visible header change. The lazy-blockchain formulation
   ([arXiv:2203.15968](https://arxiv.org/abs/2203.15968)) shows how to keep
   full nodes lazy about it. Elegant, and the only option here that preserves
   pure PoW trust while going sublinear.
3. **LightSync-style forward commitments.** Checkpoint/commitment chains let a
   client verify from a recent trusted point instead of genesis. Cheap, but
   introduces a checkpoint trust root — Harpy already documents that trade-off
   for PoS-style checkpointing in
   [POS_CHECKPOINTING.md](./POS_CHECKPOINTING.md); the same caveats apply.
4. **Committee-based clients.** A signer committee attests to sync state
   (PoS-world pattern). Reduces verification to committee trust —
   the exact property the bridge ranking rejects
   ([LIGHT_CLIENT_BRIDGES.md](./LIGHT_CLIENT_BRIDGES.md) pattern 1). Not a
   fit for a PoW chain whose point is work-based verification.
5. **Unconditionally-safe clients.** Recent work
   ([arXiv:2405.01459](https://arxiv.org/abs/2405.01459)) trades liveness for
   safety that holds even under majority adversaries — the client may stall
   but never accepts a false statement. Philosophically aligned with Harpy's
   "verification layer" role; worth tracking, not implementing.

## Verdict

- **Do nothing now.** Full-header SPV is correct relative to its explicit
  trusted-tip/checkpoint assumption, simple, and cheap at any plausible Harpy
  scale; superlight sync solves a size problem Harpy does not have. A tip
  obtained from the same proof server is not a trust root.
- **If sublinear sync is ever needed, NIPoPoW is the chosen design** (option
  2): it is the only sublinear option with no new trust assumption. The
  upgrade cost is one header field (interlink commitment) — schedule it with
  any other header change at a reset boundary of the staging testnet
  ([TESTNET.md](./TESTNET.md)), since it is consensus-visible.
- **Header discipline is the real deliverable.** Keep the header compact,
  fixed-field, and cheap to PoW-verify (MIC-80 rules in
  [LIGHT_CLIENT_BRIDGES.md](./LIGHT_CLIENT_BRIDGES.md)); that keeps options
  2 and 5 open without further design debt.
