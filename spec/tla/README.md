# Formal verification — TLA+ consensus spec (MIC-70)

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

## Scope

This abstracts a block to `(parent, work)`. Transaction/UTXO validity, coinbase
rules, and the per-block undo log ([state.cr](../../src/harpy/state.cr)) are
covered by the Crystal suite — including the consensus-layer chaos harness in
[../chaos_harness_spec.cr](../chaos_harness_spec.cr). MIC-78 (an alternative
PoW-specific model check) can extend this module.
