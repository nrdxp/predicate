# Synthetic tagged-provenance fixture — because refs carry a corpus/external tag

`signer:: agent/composer` · `at:: abc1234`

CORRECTED under ruling-provenance-representation (ledger commit f257f6f),
which WITHDRAWS the entry-level `external_refs` mirror this fixture originally
pinned — see 2026-08-12-failure-states for the staleness episode that produced.
The ruled shape: the extractor's `because` field carries TAGGED refs, a record
naming `corpus` or `external`, and only `because` carries them — `depends`
stays a plain corpus id. No sidecar key survives; provenance is emitted once,
on the entry that states it.

## Claims

`[K1] grade::proved` The floor vocabulary is fixed by the entry contract.
`check:: bash ledger/gate/test_entry.sh`

`[X1] grade::synthesis` Support names one corpus antecedent and one that
structurally cannot be a corpus entry, on the same node. `derives-from:: [K1],
[[prior-art/typed-ledgers]]`
