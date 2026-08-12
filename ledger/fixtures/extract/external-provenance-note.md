# Synthetic external-provenance fixture — a claim's sole provenance is external

`signer:: agent/composer` · `at:: abc1234`

This fixture isolates the ProvenanceGate fix's target shape (ruling-provenance-
gate, ledger commit fcf009e): a synthesis claim whose derives-from span names
NO bracketed corpus ref at all, only a wikilink — so the extractor's because
edge stays absent, and the new per-entry field the extractor mirrors from its
own share of the external_refs sidecar is the ONLY thing carrying its
provenance. This is the shape 20 of the ruling's 22 no-derivation-edge claims
actually have.

## Claims

`[X1] grade::synthesis` The floor vocabulary generalizes to typed ledgers
elsewhere. `derives-from:: [[prior-art/typed-ledgers]]`
