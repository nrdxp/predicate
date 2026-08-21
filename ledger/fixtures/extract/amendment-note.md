# Synthetic amendment fixture — recovered edges, designations, axes

`signer:: agent/composer` · `at:: abc1234`

This fixture is SYNTHETIC: it exercises the amendment's grammar feature by
feature - closure and supersession edges, closer designations with the legacy
machine alias, and the axes and freshness productions - so its expected
extraction is exact by construction. R1 and Q2 are discharged, Q3 is
superseded, R2 and Q1 stay open: the query views over this corpus prove the
openness filter and the chain-floor report.

The two non-`closed` floors bottom out through QUESTIONS (Q4, Q5), which is
the only shape left that can reach them: ProvenanceGate requires every
unclosed CLAIM to carry a resolvable derivation edge, so a claim can no
longer be an edge-free leaf, and `edges_of` is derivation-only — an external
ref satisfies nothing. A question asserts no truth-value, so it is
legitimately edge-free, and support that bottoms out in one is exactly what
`unbacked` reports.

## Claims

`[K1] grade::proved` The ratification landed and the entry gate is green.
`check:: bash ledger/gate/test_entry.sh` `axes:: +determined +certifiable +monotone`
`discharges:: [R1]`

`[K2] grade::cited` The alias ruling covers the legacy corpus.
`source:: the pen-law ratification log` `axes:: +determined -certifiable -monotone`
`freshness:: re-run the closer census at reconcile` `discharges:: [Q2]`

`[X1] grade::synthesis` Openness is derivable once closure is an edge.
`derives-from:: [K1]` `axes:: -determined +monotone`

`[X2] grade::synthesis` The derived view will replace the authored one.
`derives-from:: [X1], [X4]`

`[X3] grade::synthesis` External support bottoms out outside the corpus.
`derives-from:: [Q4]`

`[X4] grade::synthesis` A proposal resting on an open question bottoms out
unbacked. `derives-from:: [Q5]`

## Questions

`[R1] grade::routed` Ratify the closer designation shape.
`discharge:: the head rules once` `closer:: human/nrd`

`[R2] grade::routed` Approve the composer's pen follow-on.
`discharge:: the head rules the follow-on` `closer:: human/nrd` `supersedes:: [Q3]`

`[Q1] grade::dispatchable` Does the extract suite cover the alias?
`discharge:: run the extract suite` `closer:: machine`

`[Q2] grade::dispatchable` Does the census survive the new tokens?
`discharge:: run the census cases` `closer:: machine`

`[Q3] grade::routed` Ratify the designation shape, asked a second time.
`discharge:: the head rules once` `closer:: human/nrd`

`[Q4] grade::frontier` Which typed-ledger prior art fixes the edge vocabulary?
`discharge:: read the cited work and rule` `closer:: machine`
`derives-from::` [[prior-art/typed-ledgers]]

`[Q5] grade::frontier` What governs a claim whose support is still a question?
`discharge:: rule it at the next reconcile` `closer:: machine`
