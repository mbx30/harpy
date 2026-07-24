# Bridge threat model and launch gates (MIC-85)

Cross-chain bridges are the dominant loss vector in the industry: **69% of all
funds stolen in 2022** were taken from bridges (Chainalysis), and the SoK of
bridge security [arXiv:2403.00405](https://arxiv.org/abs/2403.00405) analyzing
60 bridges and 34 exploits finds the failures concentrate in a handful of
repeated patterns. Harpy has **no bridge today**; this model exists so that if
one is ever proposed, the launch gates below are already binding.

Companion docs: monitoring requirements
([BRIDGE_MONITORING.md](./BRIDGE_MONITORING.md)), verification patterns
([LIGHT_CLIENT_BRIDGES.md](./LIGHT_CLIENT_BRIDGES.md)), oracle trust
([ORACLE_PATTERNS.md](./ORACLE_PATTERNS.md)).

## Threat classes

1. **False deposit events.** The bridge mints/releases on the destination
   because it believed a deposit happened on the source when it didn't —
   forged or replayed event proofs, unverified emitters. (Qubit, ~$80M: a
   deposit function that could be called with no deposit.)
2. **Validator-set / relayer key compromise.** A multisig or PoA relayer set
   is the whole security budget; steal enough keys and the bridge is a
   printing press. Ronin, ~$600M: 5 of 9 validator keys. Threshold designs and
   rotation policy: [THRESHOLD_MULTISIG.md](./THRESHOLD_MULTISIG.md),
   [KEY_ROTATION.md](./KEY_ROTATION.md).
3. **Unaudited upgrade paths.** Proxy-upgradeable bridge contracts let whoever
   controls the admin key rewrite verification logic in place (Nomad, ~$190M:
   a routine upgrade zeroed a trusted-root check and made every message
   provable).
4. **Verification-logic bugs.** Signature or proof verification that can be
   bypassed outright (Wormhole, ~$325M: unverified guardian signature path).
5. **Source-chain finality failures.** Accepting deposits before the source
   chain's reorg window closes converts an ordinary reorg into a double-spend
   against the bridge. For a PoW source like Harpy, confirmation depth must
   come from [CONFIRMATION_DEPTH.md](./CONFIRMATION_DEPTH.md), and the k-deep
   reorg trace demonstrated by the model checker
   ([spec/tla/README.md](../spec/tla/README.md), MIC-78) is exactly the attack.

## Launch gates

No Harpy bridge ships unless **all** of these hold:

- **Gate 1 — external audit.** No custody bridge without an independent
  external audit of the full deposit→mint and burn→release paths. Non-custodial
  anchoring (hash-on-chain, [AUDIT_LOG_ANCHORING.md](./AUDIT_LOG_ANCHORING.md))
  remains the preferred integration and needs no bridge at all.
- **Gate 2 — monitored circuit breaker.** Continuous monitoring per
  [BRIDGE_MONITORING.md](./BRIDGE_MONITORING.md) wired to an automatic pause:
  rate-limited mints, anomaly halt, and a manual kill switch with a named
  on-call owner ([INCIDENT_RESPONSE.md](./INCIDENT_RESPONSE.md)).
- **Gate 3 — verification over trust.** Prefer light-client/zk verification of
  the source chain over trusted multisig relays
  ([LIGHT_CLIENT_BRIDGES.md](./LIGHT_CLIENT_BRIDGES.md)). If a committee is
  unavoidable: threshold signatures, geographic/organizational key diversity,
  documented rotation, and a quorum that survives any single organization.
- **Gate 4 — governed upgrades.** Timelocked upgrades, audit diff published
  before activation, and monitoring that alerts on any admin/upgrade
  transaction (an unannounced upgrade is treated as an active incident).
- **Gate 5 — finality margin.** Destination-side crediting waits out the
  source-chain confirmation depth with explicit margin; the parameter is
  documented and revisited whenever difficulty or hashrate assumptions change.

Default posture: Harpy stays an anchoring/verification layer. A bridge is an
optional milestone precisely because the honest cost of doing it safely —
audit + monitoring + light-client verification — exceeds the tutorial value of
having one.
