# Confirmation depth (Gervais MDP framework)

Harpy uses proof-of-work **probabilistic finality**: a transaction buried *k* blocks deep is harder to reverse via a private fork, but never mathematically final in the classical sense. This document parameterizes the [Gervais et al. MDP framework](https://eprint.iacr.org/2016/555) for Harpy's assumptions and recommends confirmation depth *k* for a target attack success probability.

**Do not copy Bitcoin's 6 confirmations or Ethereum's informal equivalents blindly.** Gervais et al. show Ethereum needed on the order of **~37 confirmations** to match Bitcoin's security at comparable attacker hash power, because block interval and stale-block rate differ.

## Harpy parameters (tutorial defaults)

| Parameter | Symbol | Harpy default | Notes |
|-----------|--------|---------------|-------|
| Block interval target | Δ | **60 s** | Tutorial target after [MIC-58](https://linear.app/mbx2/issue/MIC-58) retargeting |
| PoW difficulty | *d* | **3** hex zeros (genesis) | Adjustable every `RETARGET_INTERVAL` blocks |
| Stale-block rate | *s* | **0.05** (5%) | Placeholder until P2P measurement; Bitcoin ~1–2%, fast chains higher |
| Attacker hash fraction | *q* | **0.25** | Selfish-mining-relevant region; see [SELFISH_MINING.md](./SELFISH_MINING.md) |
| Network nodes | *n* | **1** (today) | Revisit when P2P ships ([MIC-54](https://linear.app/mbx2/issue/MIC-54)) |
| Block reward | *R* | `50_000_000` base units | [STATE_MODEL.md](./STATE_MODEL.md) §6 |
| Transaction value | *v* | operator-defined | Compare to *R* + fees in the MDP |

These are **educational defaults**. Production-like deployments must remeasure *s*, Δ, and *q* on the live network.

## MDP intuition

Gervais models PoW as a Markov decision process where an attacker chooses when to publish a private fork. State includes lead/lag vs the honest chain, rewards collected, and costs of mining on the private branch. The **success probability** of double-spending a payment accepted at depth *k* decreases exponentially in *k* for *q* < 0.5, but the **constant factors** depend on Δ, *s*, and fee economics.

Key takeaway from §6 of the paper: **confirmation count is not portable across chains** — only the success probability is comparable when parameters are aligned.

## Recommended depth *k* (Harpy tutorial)

Computed with the Gervais-style approximation for PoW chains (attacker *q* = 25%, stale rate *s* = 5%, Δ = 60 s), targeting **double-spend success ≤ 0.1%** for high-value transfers:

| Acceptance risk | Recommended *k* | Wall-clock wait (Δ = 60 s) |
|-----------------|-----------------|----------------------------|
| ≤ 1% | **4** | ~4 min |
| ≤ 0.1% | **6** | ~6 min |
| ≤ 0.01% | **8** | ~8 min |

For **low-value** tutorial demos (faucet, classroom), **3** confirmations (~3 min) may suffice if the operator accepts ~1% reorg risk under the same assumptions.

### Comparison table (illustrative)

| Chain style | Δ | Typical *k* for ~0.1% risk | Harpy equivalent |
|-------------|---|------------------------------|------------------|
| Bitcoin | ~600 s | ~6 | — |
| Ethereum (2016 analysis) | ~15 s | ~37 | — |
| Harpy (tutorial) | 60 s | **6** | Use this row |

## How to recompute

1. Fix **q** (attacker hash share), **Δ** (retargeted block time), and **s** (measured stale/orphan rate on P2P testnet).
2. Use the Gervais MDP solver ([IACR ePrint 2016/555](https://eprint.iacr.org/2016/555), §5–6) or a Monte Carlo private-chain simulator.
3. Find smallest *k* such that `P(double-spend success) ≤ ε` for your tolerance ε.
4. Add **coinbase maturity** ([MIC-62](https://linear.app/mbx2/issue/MIC-62)): miner rewards require `COINBASE_MATURITY = 100` blocks before spend — separate from payment confirmation depth.
5. Document the result in operator runbooks ([DEMO.md](./DEMO.md)) and revisit after difficulty retargeting or P2P launch.

## Operator guidance

| Scenario | Suggested *k* |
|----------|---------------|
| Local dev (single node) | 1 (chain tip is authoritative) |
| Classroom / demo LAN | 3 |
| Staging with untrusted writers | 6 |
| Any real value | **Not supported** — Harpy is educational; remeasure on a production fork |

Expose `confirmations` on `GET /validate` or per-tx status in a future API ([MIC-55](https://linear.app/mbx2/issue/MIC-55) finality doc).

## Related documents

- [SELFISH_MINING.md](./SELFISH_MINING.md) — attacker hash threshold vs γ
- [STATE_MODEL.md](./STATE_MODEL.md) — UTXO, coinbase maturity
- [THREAT_MODEL.md](./THREAT_MODEL.md) — consensus threats
- Gervais et al., [On the Security and Performance of Proof of Work Blockchains](https://eprint.iacr.org/2016/555)
