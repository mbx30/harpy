# Formal verification — TLA+ consensus specs (MIC-70, MIC-78)

[`HarpyConsensus.tla`](HarpyConsensus.tla) is a TLA+ model of Harpy's
cumulative-work fork choice (`Chain#replace_if_more_work_valid!` in
[chain.cr](../../src/harpy/chain.cr)). It models a growing block tree and the
rule that the node adopts a new tip only when it has strictly more cumulative
work, then checks the core consensus-safety property.

## Properties checked

- **`TypeOK`** (invariant) — structural well-formedness of the state.
- **`WorkNeverDecreases`** (safety) — the node's tip never moves to a chain with
  less cumulative work. This is the property that makes equal-work fork and
  selfish-mining attacks unprofitable at the fork-choice layer.

`HeaviestEventuallyChosen` (liveness) is documented in the module but not in the
`.cfg`: TLC cannot evaluate a temporal formula quantifying over the growing state
variable `blocks`. `WF_vars(ReplaceTip)` supplies the fairness it would need.

## Running it

Requires Java (any 11+). Download TLC once, then run:

```bash
curl -sL -o tla2tools.jar \
  https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar
java -cp tla2tools.jar tlc2.TLC -nowarning \
  -config HarpyConsensus.cfg HarpyConsensus.tla
```

Expected result at `MaxBlocks = 5`:

```
Model checking completed. No error has been found.
... 5368 states generated, 2141 distinct states found ...
```

Raise `MaxBlocks` in `HarpyConsensus.cfg` for a larger state space (cost grows
quickly). `CHECK_DEADLOCK FALSE` is set because the model is bounded and
terminating (mining stops at `MaxBlocks`), so a terminal state is expected, not a
liveness bug.

## PoW adversary model — `HarpyPoW.tla` (MIC-78)

[`HarpyPoW.tla`](HarpyPoW.tla) is the PoW-specific companion model, following
the approach of DiGiacomo-Castillo et al., *Model checking blockchain consensus
protocols* (IEEE Blockchain 2020). Where `HarpyConsensus.tla` checks the fork
choice rule in isolation, this model races an explicit withholding adversary
against an honest miner and checks the property applications actually rely on:
**k-deep confirmation** (`CommittedStable` — a block an observer accepted at
`ConfirmDepth` confirmations is never reorged out).

Run both configurations:

```bash
# Safe: adversary budget <= ConfirmDepth. Expect: no error.
java -cp tla2tools.jar tlc2.TLC -nowarning -config HarpyPoW.cfg HarpyPoW.tla

# Attack: adversary can out-mine the depth. Expect: CommittedStable violated,
# with the textbook double-spend as the counterexample trace.
java -cp tla2tools.jar tlc2.TLC -nowarning -config HarpyPoWAttack.cfg HarpyPoW.tla
```

Verified results (TLC 2.19, 2026-07-19):

- `HarpyPoW.cfg` (`ConfirmDepth = 3`, `MaxAdvBlocks = 3`, `MaxHonestBlocks = 4`)
  — **no error**, 95,141 states generated / 44,385 distinct.
- `HarpyPoWAttack.cfg` (`ConfirmDepth = 2`, `MaxAdvBlocks = 4`) —
  **`CommittedStable` violated**: honest chain reaches height 3, the observer
  commits block 1 at depth 2, then the adversary releases a 4-block private
  fork from genesis and `Adopt` orphans the committed block. Note the
  arithmetic: a k-deep commit first happens at honest height k+1, so the
  private fork from genesis needs k+2 blocks — the reason `MaxAdvBlocks = 3`
  with `ConfirmDepth = 2` is still safe.

This is the qualitative shape behind [docs/CONFIRMATION_DEPTH.md](../../docs/CONFIRMATION_DEPTH.md):
confirmation depth must exceed the adversary's plausible private lead, and the
Gervais MDP framework turns that into a probability given a hashrate share.

## Scope

Both modules abstract a block to `(parent, work)`. Transaction/UTXO validity,
coinbase rules, and the per-block undo log ([state.cr](../../src/harpy/state.cr))
are covered by the Crystal suite — including the consensus-layer chaos harness
in [../chaos_harness_spec.cr](../chaos_harness_spec.cr).
