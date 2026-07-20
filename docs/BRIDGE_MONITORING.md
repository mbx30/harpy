# Bridge monitoring requirements (MIC-89)

If Harpy ever connects to an external chain, the bridge runs under continuous
detection from day one — BridgeShield-style monitoring
([arXiv:2508.20517](https://arxiv.org/abs/2508.20517)) treats the bridge as a
stream of cross-chain events and flags the invariant violations that preceded
every major bridge loss. These are **requirements**, binding via Gate 2 of
[BRIDGE_THREAT_MODEL.md](./BRIDGE_THREAT_MODEL.md); a bridge without this
monitoring does not launch.

## Invariants watched

1. **Deposit↔mint conservation (false deposit events).** Every destination
   mint must map 1:1 to a finalized source deposit, matched on (tx, amount,
   recipient, nonce). Alert on: mint without matching deposit, amount
   mismatch, nonce replay, or aggregate minted > aggregate locked (the
   Nomad/Qubit signature). Source-side finality means Harpy confirmation
   depth per [CONFIRMATION_DEPTH.md](./CONFIRMATION_DEPTH.md), not mere
   inclusion.
2. **Validator-set compromise signals.** Alert on: any relayer/validator key
   signing from a new address or ASN, signature quorum reached faster than
   plausible independent operation, off-schedule signer-set changes, and any
   deviation from the rotation policy in [KEY_ROTATION.md](./KEY_ROTATION.md).
   A quorum of signatures is not evidence of honesty — Ronin's 5-of-9 was
   "valid" — so volume/velocity anomalies on validly-signed withdrawals are
   first-class alerts.
3. **Upgrade-path integrity.** Any admin, proxy-upgrade, or parameter-change
   transaction triggers an immediate page (not a dashboard entry). Compare
   deployed bytecode/config hash against the audited release; an unannounced
   or un-audited change is an active incident, full stop.

## Response wiring

- **Circuit breaker.** Invariant 1 violations auto-pause mints/releases;
  invariants 2–3 page a human with authority to pause. Pause authority and
  escalation follow [INCIDENT_RESPONSE.md](./INCIDENT_RESPONSE.md).
- **Rate limits as a backstop.** Per-window mint caps bound the loss from any
  undetected bypass — sized so the worst undetected window is survivable.
- **Independent vantage.** The monitor verifies source-chain events through
  its own light client ([spv.cr](../src/harpy/spv.cr) on the Harpy side), not
  through the bridge's own relayer — otherwise a compromised relayer feeds the
  monitor the same lie it feeds the bridge.
- **Liveness of the monitor itself.** Heartbeat alert if the event stream
  stalls; a silent monitor must read as an outage, not as calm.

Scope note: none of this exists today because no bridge exists. The document
is a precondition artifact — it defines what "monitored" means so Gate 2 is
concrete when the question ever comes up.
