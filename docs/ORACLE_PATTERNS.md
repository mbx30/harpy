# Oracle design patterns (MIC-83)

An oracle feeds external facts into a chain, and in doing so becomes a trust
chokepoint: consensus can be perfect while a corrupted input steers it into
provably-agreed-upon nonsense. The survey at
[arXiv:2106.09349](https://arxiv.org/abs/2106.09349) organizes the design
space; this note records the patterns and Harpy's stance. Required reading
before any contract or integration that reads off-chain data.

## The core problem

On-chain logic can verify *signatures over* a claim, never the claim itself.
Every oracle design is a different answer to "who do we trust to observe the
world, and how do we make lying expensive?"

## Patterns

1. **Single-signer feed.** One key posts values. Trivial to build, and the
   whole system's integrity equals that one key — acceptable only for demos
   or values the signer already unilaterally controls. This is the only
   pattern Harpy's tutorial scope would ever justify, and it must be labeled
   as trusted input, not "oracle data".
2. **Voting/median committee.** N independent reporters; the contract takes a
   median or quorum answer (Chainlink-style). Tolerates < N/2 corrupt
   reporters *if* they are genuinely independent — committee diversity is the
   real security parameter, same as bridge validator sets
   ([BRIDGE_THREAT_MODEL.md](./BRIDGE_THREAT_MODEL.md)).
3. **Reputation/stake-weighted.** Reporters bond stake that is slashed on
   provable misreporting, or accrue weight from track record. Turns "lying is
   free" into "lying costs the bond" — but only for disputes that can be
   objectively adjudicated on-chain.
4. **TEE-backed.** A trusted execution environment (SGX-class) attests that a
   known program fetched the data (Town Crier lineage). Strong against the
   operator, but inherits every TEE side-channel and the vendor attestation
   root as a single point of failure — a hardware CA replaces the signer.

Orthogonal to all four: **commit–reveal** (prevents reporters copying each
other or front-running), **freshness bounds** (reject stale rounds), and
**deviation guards** (a reading that jumps beyond a plausibility band pauses
consumers instead of settling them — the flash-loan price-manipulation lesson:
never read a spot value an attacker can move within one block).

## Harpy's stance

- **Minimize.** The validated integration direction is the reverse of an
  oracle: Harpy *attests outward* (anchoring,
  [AUDIT_LOG_ANCHORING.md](./AUDIT_LOG_ANCHORING.md)); it does not consume
  external truth. No oracle should exist while that remains true.
- **Decentralize if ever needed.** If a future contract needs external data,
  start at pattern 2 with an explicit committee-independence argument, add
  commit–reveal and deviation guards, and treat the reporter set under the
  same key-rotation and monitoring discipline as a bridge validator set
  ([KEY_ROTATION.md](./KEY_ROTATION.md),
  [BRIDGE_MONITORING.md](./BRIDGE_MONITORING.md)).
- **Gate.** Like the VM and bridge surfaces: threat-model note first, then
  code. An oracle PR without its trust analysis does not merge.
