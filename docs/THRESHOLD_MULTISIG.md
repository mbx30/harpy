# Threshold / multi-signature key management design (MIC-73)

**Status:** design doc (educational). Harpy does not implement threshold signing;
this records the design so the signature format and opsec are ready for it.

## Why

Single-key custody is the dominant real-world loss vector — not broken crypto,
but stolen keys. The Ronin bridge lost ~$600M when an attacker obtained 5 of 9
validator keys. The mitigation is to ensure **no single machine ever holds a
spendable key**: split signing authority so a threshold *t* of *n* parties must
cooperate.

## Two approaches

| | Multisig (n-of-m at protocol level) | Threshold signatures (TSS) |
|---|---|---|
| On-chain footprint | m signatures / script; larger | single signature; indistinguishable from 1-of-1 |
| Key material | m independent keys | one logical key, secret-shared; never reconstructed |
| Complexity | simple to verify | needs DKG + signing protocol |
| Refs | Bitcoin script multisig | Boneh et al. [ePrint 2018/483](https://eprint.iacr.org/2018/483), threshold ECDSA [ePrint 2020/498](https://eprint.iacr.org/2020/498), DKG [arXiv:2102.09041](https://arxiv.org/abs/2102.09041) |

For Harpy's Ed25519 base, the natural TSS path is **FROST**-style threshold
Schnorr/EdDSA: a distributed key generation (DKG) produces key shares and a single
group public key; *t* of *n* shares produce one standard Ed25519 signature that
verifies with the existing `Crypto.verify` — no consensus/verifier change needed.

## How it maps onto Harpy

- **Signature format:** unchanged. A threshold signature is a normal Ed25519
  signature over the transaction digest; verifiers cannot tell it apart. The
  crypto-agile `sig_algorithm` field (MIC-66) already allows introducing a
  distinct identifier later (e.g. `ed25519-frost`) if policy metadata is wanted.
- **Address format:** the group public key encodes as an ordinary `harpy1…`
  address ([KEY_ROTATION.md](./KEY_ROTATION.md), [crypto.cr](../src/harpy/crypto.cr)).
- **What must be built (out of scope now):** DKG ceremony, share storage (HSM /
  separate hosts), a signing coordinator, and share-refresh (proactive secret
  sharing) so shares rotate without changing the group key.

## Policy recommendations

- High-value miner/treasury keys: **t ≥ 2**, shares on separate hosts/HSMs, no
  share on an internet-exposed node.
- Prefer refreshable shares (proactive SS) so a slow leak of one share over time
  does not accumulate toward the threshold.
- Threshold changes and share refresh follow the rotation procedure in
  [KEY_ROTATION.md](./KEY_ROTATION.md).

## Non-goals

No implementation, no HSM integration, no on-chain governance of signer sets —
Harpy is a single-node educational chain. This design exists so those additions
would not require a breaking signature/address change.
