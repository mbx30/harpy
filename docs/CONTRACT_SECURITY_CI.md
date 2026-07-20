# Smart contract security CI (MIC-84)

If Harpy executes contracts, every change to the execution surface must pass a
security pipeline **before** it can ship. The gate is enforced by
[.github/workflows/contract-security.yml](../.github/workflows/contract-security.yml),
which blocks merges touching [vm.cr](../src/harpy/vm.cr) or its specs until
three stages pass: static analysis, execution-semantics property tests, and
seeded fuzzing.

Threat context: [SMART_CONTRACT_THREAT_MODEL.md](./SMART_CONTRACT_THREAT_MODEL.md).

## Mapping the EVM toolchain onto Harpy

The reference pipeline for EVM chains (per the analysis-methods survey
[arXiv:1908.08605](https://arxiv.org/abs/1908.08605)) is *static analysis +
symbolic execution + fuzzing* on every contract before deployment — Slither,
Mythril/Manticore, Smartian/sFuzz/ConFuzzius. Harpy's VM is a teaching
artifact in Crystal, so each stage maps to the strongest native equivalent:

| EVM-world stage | Tool there | Harpy stage |
|---|---|---|
| Static analysis | Slither | `crystal tool format --check` + `crystal build --error-on-warnings` (type system + strict warnings) |
| Symbolic execution / model | Mythril, Manticore | Exhaustive-by-construction property tests over execution semantics ([vm_spec.cr](../spec/vm_spec.cr)); consensus layer separately model-checked in [spec/tla](../spec/tla/README.md) |
| Fuzzing | Smartian, sFuzz | Seeded random + opcode-biased program fuzzing ([vm_fuzz_spec.cr](../spec/vm_fuzz_spec.cr)) |

Formal verification of individual high-value contracts (survey
[arXiv:2008.02712](https://arxiv.org/abs/2008.02712)) stays out of scope until
Harpy has real contracts; the VM itself is the verification target today.

## What the fuzz stage guarantees

Reproducible (fixed seed, printed on failure) checks that hold for *arbitrary*
byte strings, not just well-formed programs:

- **Never crash** — any program either halts normally or returns a typed error
  (`OutOfGas`, `StackUnderflow`, `InvalidJump`, …); no exceptions escape.
- **Determinism** — identical program + gas + storage ⇒ identical result.
- **Gas conservation** — `gas_used + gas_remaining == gas_limit`, always.
- **Gas monotonicity** — more gas never changes a successful outcome.
- **Bounded resources** — stack depth ≤ 1024 for every input.
- **Atomic state** — failed executions leave caller storage untouched.

## Deployment gate

- A red run on any stage blocks the merge; there is no manual override lane.
- New opcodes require: gas cost assigned in the schedule, property tests for
  the new semantics, and a fuzz corpus that reaches them (the opcode-biased
  generator picks up new `OpCode` members automatically).
- Changes to the gas schedule are consensus-relevant once contracts execute
  on-chain — treat them like fork-choice changes (AGENTS.md protected paths,
  independent review required).
