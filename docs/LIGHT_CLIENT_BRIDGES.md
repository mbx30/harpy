# Light-client and zk bridge patterns (MIC-90)

Research gate before any interoperability work: which verification pattern
would a Harpy bridge use? The ranking is driven by the exploit record — the
SoK [arXiv:2403.00405](https://arxiv.org/abs/2403.00405) (60 bridges, 34
exploits), the interoperability survey
[arXiv:2505.04934](https://arxiv.org/abs/2505.04934), and the bridge-hack
review [arXiv:2501.03423](https://arxiv.org/abs/2501.03423) all point the same
way: losses concentrate in **trusted-relay** designs, so verification should be
cryptographic, not committee-based. Depends on
[BRIDGE_THREAT_MODEL.md](./BRIDGE_THREAT_MODEL.md); launch gates there apply.

## The spectrum, weakest to strongest trust minimization

1. **Trusted multisig relay.** A committee attests "event X happened on chain
   A." Cheapest to build; the committee *is* the bridge's entire security
   (Ronin, Multichain). Ruled out for Harpy by Gate 3 unless every
   threshold/rotation/monitoring requirement is met — and even then it is the
   fallback, not the design.
2. **Optimistic verification.** Claims post with a bond and a challenge
   window; watchers fraud-prove lies (Nomad's model). Honest-minority
   assumption is attractive, but adds latency and requires a live, funded
   watcher ecosystem — thin for an educational chain.
3. **On-chain light client (IBC-style).** The destination chain runs a light
   client of the source: it verifies headers and inclusion proofs itself, so
   trust reduces to the source chain's own consensus. This is the pattern
   Harpy is *already built for*: header sync + SPV proofs exist
   ([spv.cr](../src/harpy/spv.cr), [block_header.cr](../src/harpy/block_header.cr),
   `GET /headers`, `GET /proof/...`). A counterpart chain verifying Harpy
   needs exactly: header-chain PoW validation + cumulative-work fork choice +
   Merkle inclusion — all specified, tested, and model-checked here.
4. **zk bridge.** A succinct proof ("I verified source-chain consensus for
   this header range") replaces re-running verification (zkBridge lineage).
   Strongest trust profile and cheapest destination-side verification, at the
   cost of prover complexity far beyond Harpy's scope — but note the design
   consequence below.

## Consequences for Harpy

- **Preferred order: 3 > 4 > 2 > 1.** An on-chain light client of Harpy is the
  natural first bridge; zk verification of the same header chain is the
  upgrade path, not a rewrite, because both consume the identical header
  format.
- **Keep headers verification-friendly.** The compact fixed-field header
  (MIC-80) is the bridge interface. Any header change must preserve: cheap
  PoW check, parent linkage, and Merkle roots for tx/anchor inclusion —
  that's what makes patterns 3 and 4 possible later.
- **Committee-hardening applies regardless.** Even light-client bridges keep a
  relayer role (submitting headers). Relayers in pattern 3 can censor but not
  forge — that asymmetry is the entire point.
- **NIPoPoW-style superlight proofs** would shrink what a counterpart chain
  must store; evaluated separately in
  [NIPOPOW_EVALUATION.md](./NIPOPOW_EVALUATION.md).

Bottom line: no interoperability work starts from a multisig. If a bridge is
ever justified, it starts from the SPV surface Harpy already ships.
