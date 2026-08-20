# Synthetic mixed-floor fixture — an external branch beside an internal one

`signer:: agent/composer` · `at:: bcd2345`

This fixture is SYNTHETIC: it isolates the one chain-floor shape the amendment
golden cannot reach. There, every claim's floor set arrives through derivation
edges alone, and `external` is only ever reached from an edge-free leaf — so a
floor set that must carry `external` BESIDE an internal verdict is unpinned,
and a walk that follows edges while discarding the entry's own external refs
reads identically to a correct one.

X1 branches at a single node: one resolvable derivation edge onto a
corroborated claim, and one wikilink the corpus cannot follow. Its support
therefore bottoms out in two places at once, and a report naming only the
first is a clean bill the record does not support.

X2 rests on X1 alone, so it pins the same union PROPAGATING. A repair applied
where the query assembles its rows, rather than inside the fixed point the
rows are read from, would satisfy X1 and lose X2.

## Claims

`[K1] grade::proved` The floor vocabulary is fixed by the entry contract.
`check:: bash ledger/gate/test_entry.sh` → EXIT=0.

`[X1] grade::synthesis` Support branches into the corpus and out of it at the
same node. `derives-from:: [K1], [[prior-art/floor-vocabulary]]`

`[X2] grade::synthesis` The mixed floor set propagates to what rests on it.
`derives-from:: [X1]`
