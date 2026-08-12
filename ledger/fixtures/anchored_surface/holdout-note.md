# Synthetic holdout fixture — the ranker's own evaluator, hand-scored

`signer:: agent/test` · `at:: 3333333`

SYNTHETIC, exact by construction, built to pin criterion 8's holdout check on a
fixture small enough to score by hand rather than trust to the real corpus (see
the suite's own real-corpus section for why the real corpus cannot referee this
today).

The holdout scans EVERY entry carrying a derivation edge, not a hand-picked
subset — the provenance gate already requires every unclosed claim to name
one, so `D1` and `SEED1` below each contribute a pair whether or not they were
written as "the test case." Four pairs total, in the entries' own extraction
order (deriving entry -> what it derives from):

1. `D1 -> SEED1` — HIT. `SEED1` is unclosed: a member.
2. `E1 -> D1`    — HIT. `D1` is unclosed: a member.
3. `E2 -> D2`    — MISS. `D2` is CORROBORATED (proved): backed, so it is
   never a member of the open surface regardless of distance — anchoring on
   `E2` can never surface it. This is not a reachability defect; it is the
   open-surface restriction applied to the deriving entry's own target, and
   it is the shape of finding the boundary's criterion 8 asked this suite to
   be able to name rather than paper over.
4. `SEED1 -> Q1` — HIT. `Q1` is an open, unclosed question: a member.

Golden rate: 3 hits / 4 total = 0.75. Independently re-derived by a throwaway
reference script over the extractor's own export before this number was
pinned into the suite — see the node's report for that verification.

## Claims

`[D1] grade::synthesis` The deliberate HIT pair's target — unclosed, so it is
a member of the open surface and reachable from E1. Its own required
derivation edge (pair 1 above) is also a HIT.
`derives-from:: [SEED1]`

`[E1] grade::synthesis` The deliberate HIT pair's deriving entry — anchoring
here must surface D1.
`derives-from:: [D1]`

`[D2] grade::proved` The deliberate MISS pair's target — corroborated, so it
is backed and can never appear in the open surface no matter how it is
reached.
`check:: true; at 3333333`

`[E2] grade::synthesis` The deliberate MISS pair's deriving entry — anchoring
here must NOT surface D2, because D2 fails open-surface membership by itself,
not by distance.
`derives-from:: [D2]`

`[SEED1] grade::synthesis` D1's own required derivation edge (the provenance
gate leaves no unclosed claim edge-free) — a HIT in its own right (pair 4
above), not a bystander.
`derives-from:: [Q1]`

## Questions

`[Q1] grade::frontier` SEED1's own derivation target, open and unclosed —
keeps the fixture's provenance chain resolvable without pulling in anything
from outside this document.
`discharge:: SEED1's own required edge target; scores as pair 4 above`
`closer:: agent/test`
