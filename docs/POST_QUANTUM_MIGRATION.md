# Post-quantum migration planning (MIC-79)

**Status:** planning doc. Not an emergency, but PQ signature sizes materially
affect block size and throughput, so the format must be ready before migration is
forced. Harpy's crypto-agility scaffolding (MIC-66) exists for exactly this.

## The threat

Ed25519 (like all ECC/RSA) is broken by a large-scale quantum computer running
Shor's algorithm: an adversary could forge signatures and spend others' UTXOs.
Hash-based commitments (block hashes, Merkle roots, `txid`) rely on SHA-256 and
are only weakened (Grover, quadratic) — a concern for a distant future, not the
near-term driver. **Signatures are the exposed surface.** See surveys
[arXiv:2402.00922](https://arxiv.org/abs/2402.00922) and
[arXiv:2510.09271](https://arxiv.org/abs/2510.09271).

## Candidate algorithms

| Scheme | Type | Signature size | Notes |
|--------|------|----------------|-------|
| Ed25519 (today) | classical | 64 B | quantum-vulnerable |
| ML-DSA (Dilithium, FIPS 204) | lattice | ~2.4–4.6 KB | NIST-standardized; primary candidate |
| SPHINCS+ (SLH-DSA, FIPS 205) | hash-based | ~8–50 KB | conservative, stateless, very large |
| Hybrid (Ed25519 + ML-DSA) | both | sum of both | classical security until PQ is trusted |

## Throughput impact (the real planning issue)

A transaction input today carries a 64 B signature. Under ML-DSA that becomes
~3 KB — a **~50×** increase per input. With `MAX_BLOCK_DATA_BYTES = 32 KiB` and
`MAX_TXS_PER_BLOCK = 100` ([economics.cr](../src/harpy/economics.cr)), PQ
signatures would drastically cut transactions-per-block unless limits grow. This
must be modeled before migration, not discovered at cutover.

## Migration path (enabled by MIC-66)

The address and signature formats are already algorithm-tagged
([crypto.cr](../src/harpy/crypto.cr)): `TxInput.sig_algorithm` and the address
`algo_id` byte identify the scheme, so new algorithms are additive, not breaking.

1. **Add** an `ADDRESS_ALGO_IDS` entry + a `Crypto.verify` branch for the PQ (or
   hybrid) scheme. Old Ed25519 addresses/signatures keep verifying.
2. **Hybrid window.** Prefer hybrid (classical ‖ PQ) so security holds even if the
   PQ implementation is later found weak; require *both* to verify.
3. **Raise limits** (`MAX_BLOCK_DATA_BYTES`, block/tx caps) to absorb PQ sizes;
   re-tune fees per byte so large signatures pay their weight.
4. **Deprecate** Ed25519-only addresses on a published timeline; encourage users
   to move UTXOs to PQ/hybrid addresses (normal spends, per [KEY_ROTATION.md](./KEY_ROTATION.md)).
5. **Do not** change hash/Merkle constructions — SHA-256 stays.

## Non-goals

No PQ implementation, no shard dependency, no timeline commitment. The deliverable
is that migration is a *feature addition* on the existing crypto-agile format, not
a hard fork of the transaction structure.
