# Selfish-mining profitability threshold for Harpy

Harpy is a **single-node tutorial chain** today; selfish mining becomes a live consensus threat once P2P and multi-miner races exist ([MIC-54](https://linear.app/mbx2/issue/MIC-54)). This document records the **profitability threshold** as a function of network connectivity so operators do not assume a naive **51%** rule.

## Model parameters

| Symbol | Meaning |
|--------|---------|
| **α** | Attacker fraction of total hash power (0 < α < 1) |
| **γ** | Connectivity: fraction of honest miners that adopt the attacker's block when competing with an honest block (0 ≤ γ ≤ 1) |

**γ = 0** — honest miners never build on the attacker's withheld blocks; the attacker must publish first to win races.

**γ = 0.5** — ties split evenly (classic Eyal & Sirer assumption for well-connected networks).

**γ → 1** — attacker is highly connected; most honest miners follow the attacker's chain when it appears.

## Published thresholds (do not copy 51% blindly)

| Model | Threshold | γ assumption |
|-------|-----------|--------------|
| Eyal & Sirer (2014) | **25%** | γ = 0.5 |
| Eyal & Sirer (2014) | **33%** | γ = 0 |
| Sapirshtein et al. MDP-optimal (2016) | **≈23.21%** | optimal strategy over γ |
| Extreme connectivity | **as low as ~0.9%** | γ = 0.99 |

References: [Selfish Mining (arXiv:1311.0243)](https://arxiv.org/abs/1311.0243), [Optimal Selfish Mining (arXiv:1602.09065)](https://arxiv.org/abs/1602.09065).

## Harpy-specific posture (today)

| Factor | Harpy today | Implication |
|--------|-------------|-------------|
| P2P | None — HTTP single node | No multi-miner races; selfish mining is **theoretical** |
| Fork choice | Cumulative PoW work (`16^difficulty` per block) | Correct for comparing forks; does not stop withholding once P2P exists |
| Propagation | N/A | **γ is unknown** until peer topology is measured |
| Confirmation policy | See [CONFIRMATION_DEPTH.md](./CONFIRMATION_DEPTH.md) | Depth *k* reduces reorg risk; not a substitute for eclipse hardening |

**Do not assume 51%.** When Harpy gains P2P, recompute the effective threshold using measured **γ** (stale-block rate, orphan rate, propagation latency) from a testnet or lab deployment.

## Recompute when P2P topology is known

1. **Measure γ** — run a 3+ node integration test ([MIC-67](https://linear.app/mbx2/issue/MIC-67)): inject withheld blocks and record how often honest nodes build on the attacker's tip vs an honest tip.
2. **Plug into MDP** — use Sapirshtein et al. optimal selfish-mining calculator or Monte Carlo over the measured γ distribution.
3. **Set operator policy** — document minimum confirmation depth and peer-diversity requirements in [THREAT_MODEL.md](./THREAT_MODEL.md) §3.
4. **Revisit after topology changes** — γ shifts with peer count, geographic spread, and relay policy ([MIC-68](https://linear.app/mbx2/issue/MIC-68)).

## Mitigations (roadmap)

| Mitigation | Issue | Notes |
|------------|-------|-------|
| Cumulative work fork choice | [MIC-35](https://linear.app/mbx2/issue/MIC-35) | Done — rejects equal-height weaker-PoW forks |
| Confirmation depth policy | [MIC-71](https://linear.app/mbx2/issue/MIC-71) | Gervais MDP parameterization |
| P2P relay + peer diversity | [MIC-54](https://linear.app/mbx2/issue/MIC-54), [MIC-68](https://linear.app/mbx2/issue/MIC-68) | Reduces effective γ for eclipse attackers |
| Coinbase maturity | [MIC-62](https://linear.app/mbx2/issue/MIC-62) | Limits spendability of rewards on reorged tips |

## Summary

Harpy's cumulative-work rule is necessary but **not sufficient** against selfish mining once multiple miners share a network view. Treat **~23–25%** as the starting threshold at γ ≈ 0.5; recompute when P2P is live. Until then, document the assumption and defer network-layer countermeasures to Phase 5.
