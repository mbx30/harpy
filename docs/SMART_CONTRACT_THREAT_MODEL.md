# Smart contract threat model (MIC-65)

Pre-VM gate: this document existed **before** contract execution code, per the
OWASP Smart Contract Security / a16z lifecycle discipline — threat model first,
then implementation, then the CI gate
([CONTRACT_SECURITY_CI.md](./CONTRACT_SECURITY_CI.md)) that enforces it on
every change. Harpy's execution surface is the minimal stack VM in
[vm.cr](../src/harpy/vm.cr); it exists to teach how these risks arise and how
metering and typed failure close them.

Chain-level threats live in [THREAT_MODEL.md](./THREAT_MODEL.md); this file
covers only the contract-execution layer.

## Adversary

Anyone who can get bytecode executed by a node: a program is untrusted input.
The attacker's goals, in rising severity: waste node CPU (DoS), corrupt
contract state, desynchronize nodes (consensus split via non-determinism), and
extract value (once contracts hold value).

## Vulnerability classes and Harpy's stance

Classes follow the arXiv taxonomies — analysis methods
[arXiv:1908.08605](https://arxiv.org/abs/1908.08605), detection techniques
[arXiv:2209.05872](https://arxiv.org/abs/2209.05872), QA survey
[arXiv:2311.00270](https://arxiv.org/abs/2311.00270), vulnerabilities &
mitigations [arXiv:2403.19805](https://arxiv.org/abs/2403.19805).

| Class | EVM incident shape | Harpy mitigation |
|---|---|---|
| Out-of-gas / unbounded loops | Node DoS, griefing | Gas is the only loop bound; every opcode has a cost, `OutOfGas` is a typed, deterministic result |
| Integer overflow/underflow | Balance corruption (pre-Solidity-0.8) | Wrapping `UInt64` arithmetic is *defined* semantics (`&+`, `&-`, `&*`); div/mod by zero yields 0, never a trap |
| Stack abuse | Crash / undefined behavior | Hard `MAX_STACK_DEPTH = 1024`; underflow and overflow are typed errors |
| Control-flow hijack | Jump into data, immediates | Jumps land only on `JumpDest` bytes; anything else is `InvalidJump` |
| Reentrancy | The DAO (~$60M) | No call/message opcode exists — single-program execution, no external calls to re-enter. Revisit the moment any call op is added |
| Unchecked external calls | Silent failure propagation | Same: no external calls in the instruction set |
| State corruption on failure | Partial writes observable | Failed executions return the caller's storage untouched (atomic revert) |
| Non-determinism | Consensus split | No clock, randomness, or I/O opcodes; fuzz suite asserts bit-identical replay |

The two most consequential rows are the **absent** ones: reentrancy and
external calls are eliminated by construction, not mitigated. That is the
deliberate scope cut that keeps a tutorial VM defensible.

## Gates for growing the surface

1. **New opcode** → update this table, assign gas, add property tests + fuzz
   reachability, pass the CI gate ([CONTRACT_SECURITY_CI.md](./CONTRACT_SECURITY_CI.md)).
2. **Call/message ops** (reintroduces reentrancy) → require a checks-effects-
   interactions design note and reentrancy property tests *before* code.
3. **On-chain execution** (contracts in blocks) → gas schedule becomes
   consensus-critical; changes follow the AGENTS.md protected-path review rule,
   and formal specification of the VM transition
   ([arXiv:2008.02712](https://arxiv.org/abs/2008.02712)) becomes the next gate.
4. **Value-bearing contracts** → external audit before any deployment that
   custodies real value; formal verification for high-value contracts.

Only proceed down this list if Harpy outgrows its tutorial scope — each step
is a real cost, and the default answer is "don't".
