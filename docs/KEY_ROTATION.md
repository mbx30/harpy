# Key rotation and compromise response (MIC-77)

Policy for rotating signing keys and responding to a suspected key compromise.
Cryptography intact but keys stolen is the common failure mode; rotation limits
the blast radius and a rehearsed response limits the loss.

## Key inventory

| Key | Holder | Exposure | Rotation trigger |
|-----|--------|----------|------------------|
| User/wallet signing key (Ed25519) | end user, off-node | signs `/tx` client-side | on suspected leak; periodically for high-value wallets |
| Miner payout key | miner operator | only the **public** key reaches the node (`/mine`) | on operator change or suspected leak |
| `HARPY_API_KEY` (RPC auth) | node operator | shared with API clients | on staff change, client leak, or on a schedule |
| Genesis pubkey (`HARPY_GENESIS_PUBKEY`) | chain config | baked into genesis | not rotatable without a new chain |

## Routine rotation

- **Wallet keys:** generate a new keypair, derive its `harpy1…` address
  ([crypto.cr](../src/harpy/crypto.cr)), move funds by spending existing UTXOs to
  the new address, then retire the old key. UTXO model makes this a normal
  transaction — no account-nonce coordination.
- **API key:** issue the new `HARPY_API_KEY`, roll clients over, then invalidate
  the old one. Support a brief overlap window operationally (the node reads a
  single key; stage the cutover during low traffic).
- **Miner payout key:** point new blocks at the new payout pubkey; previously
  mined coinbase outputs remain spendable by the old key until moved.

## Compromise response procedure

1. **Contain.** Rotate `HARPY_API_KEY` immediately; if a node host is suspected,
   take its write RPC offline (`HARPY_BIND_HOST=127.0.0.1` or firewall) per
   [NODE_HARDENING.md](./NODE_HARDENING.md).
2. **Move funds.** Spend all UTXOs controlled by the compromised key to a freshly
   generated key/address before the attacker can. This is the race that matters —
   have the replacement key pre-provisioned.
3. **Revoke access.** Remove the compromised operator's credentials; rotate any
   shared secrets they held.
4. **Investigate & record.** Follow [INCIDENT_RESPONSE.md](./INCIDENT_RESPONSE.md):
   timeline, scope, root cause, corrective actions.
5. **Post-incident.** Shorten rotation intervals for the affected class; consider
   threshold custody ([THRESHOLD_MULTISIG.md](./THRESHOLD_MULTISIG.md)) so a single
   future leak is not sufficient to spend.

## Constraints (tutorial scope)

- No automated rotation, key server, or on-chain revocation list.
- Coinbase maturity (`COINBASE_MATURITY = 100`) delays spendability of freshly
  mined rewards — factor this into any "move funds" timeline for miner keys.
