# Routing and BGP Partition Attack Surface

Harpy's P2P layer (Phase 5) assumes **honest network delivery between peers**. Routing and BGP-level attacks operate **below** the application protocol and can partition or eclipse nodes without breaking Harpy's cryptographic rules.

This document records the attack surface for educational operators — which mitigations Harpy implements at the node layer vs which require ISP/CDN-level defenses.

## Attack classes

| Class | Mechanism | Effect on Harpy |
|-------|-----------|-----------------|
| **BGP hijack** | AS announces prefixes it does not own | Peers become unreachable or traffic flows through attacker |
| **Partition** | Cut links between subnet groups | Competing forks; divergent UTXO views until reconnect |
| **Eclipse (routing-assisted)** | Concentrate peer connections via routing | Amplifies selfish mining / N-confirmation double-spend risk |
| **Delay / reorder** | Latency injection on relay paths | Stale blocks, orphan spikes, skewed γ for selfish-mining thresholds |

References:

- Apostolaki et al., *Hijacking Bitcoin: Routing Attacks on Cryptocurrencies*
- Tran et al., stealthier partitioning (IEEE S&P 2020)
- Erebus AS-level adversary model

## What Harpy implements (node layer)

| Control | Issue | Scope |
|---------|-------|-------|
| P2P block gossip | [MIC-54](https://linear.app/mbx2/issue/MIC-54) | Application-layer block relay |
| Orphan pool | [MIC-57](https://linear.app/mbx2/issue/MIC-57) | Out-of-order block buffering |
| Reorg + undo | [MIC-60](https://linear.app/mbx2/issue/MIC-60) | UTXO-consistent fork resolution |
| Peer limits + ban | [MIC-56](https://linear.app/mbx2/issue/MIC-56) | Misbehavior eviction |
| Eclipse countermeasures | [MIC-68](https://linear.app/mbx2/issue/MIC-68) | /16 bucketing, anchors, feelers, test-before-evict |
| Eclipse detection | [MIC-72](https://linear.app/mbx2/issue/MIC-72) | Subnet diversity monitoring (`/health` p2p fields) |
| Gossip spam reputation | [MIC-67](https://linear.app/mbx2/issue/MIC-67) | StarveSpam-style local scoring |

## What Harpy does **not** implement (out of tutorial scope)

- BGP monitoring or RPKI validation
- Multi-homed routing diversity requirements
- ISP-level anycast or DDoS scrubbing
- Tor/I2P transport (optional hardening for metadata privacy)

At tutorial scale, document these gaps and **do not claim mainnet-grade partition resistance**.

## Operator guidance

1. **Run multiple diverse peers** — bootstrap from independent hosts/subnets (`HARPY_P2P_PEERS`, `HARPY_ANCHOR_PEERS`).
2. **Watch `/health`** — `p2p.eclipse_risk: true` means peer set is concentrated; add outbound peers on other /16 subnets.
3. **Tune confirmation depth** — after P2P is live, recompute γ and minimum confirmations per [CONFIRMATION_DEPTH.md](./CONFIRMATION_DEPTH.md).
4. **Treat routing incidents as consensus incidents** — follow [INCIDENT_RESPONSE.md](./INCIDENT_RESPONSE.md) if nodes diverge after a network event.

## Relationship to other docs

- Eclipse specifics: countermeasures in code; detection in `/health`
- Selfish mining thresholds: [SELFISH_MINING.md](./SELFISH_MINING.md) — recompute when topology is known
- Sybil at P2P layer: [SYBIL_RESISTANCE.md](./SYBIL_RESISTANCE.md)

## Educational caveat

Harpy demonstrates **awareness** of routing/partition risk and node-layer mitigations. Production deployments need network operations discipline beyond this codebase.
