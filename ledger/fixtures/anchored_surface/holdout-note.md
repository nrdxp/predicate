# Synthetic backed-exclusion fixture, hand-scored

`signer:: agent/test` · `at:: 3333333`

SYNTHETIC, exact by construction, built to pin criterion 8's `--self-evaluate`
check on a fixture small enough to score by hand rather than trust to the
real corpus (see the suite's own real-corpus section for why the real corpus
cannot referee this today).

`--self-evaluate` scans EVERY entry carrying a derivation edge, not a
hand-picked subset — the provenance gate already requires every unclosed
claim to name one, so `D1` and `SEED1` below each contribute a pair whether
or not they were written as "the test case." Four pairs total, in the
entries' own extraction order (deriving entry -> what it derives from):

1. `D1 -> SEED1` — `SEED1` is unclosed: eligible, not excluded.
2. `E1 -> D1`    — `D1` is unclosed: eligible, not excluded.
3. `E2 -> D2`    — `D2` is CORROBORATED (proved): backed, so it is never a
   member of the open surface regardless of distance — anchoring on `E2`
   can never surface it. This is not a reachability question; it is the
   open-surface restriction applied to the deriving entry's own target,
   decidable from the corpus alone.
4. `SEED1 -> Q1` — `Q1` is an open, unclosed question: eligible, not
   excluded.

The golden is one number: pair 3 is the only one whose target is backed, so
EXCLUDED-BACKED is 1 of 4 pairs = 0.25. Independently re-derived by a
throwaway reference script over the extractor's own export before being
pinned into the suite — see the node's own report for that verification.

This fixture previously also pinned a "recall" number scoring whether each
eligible pair's target was two-hop reachable from its deriving entry. That
number is CUT (ruling-holdout-fate.md [HV1]/[HV4]): every pair above is a
direct derivation edge, so its target is always exactly one hop away by
construction — the fixture's own "hand-scored" reachability was the edge
list restated, never an independent measurement. The chain below (D1/E1/
SEED1/Q1) is kept because it still exercises the extractor's derivation-edge
scan over multiple entries; only the now-cut reachability claim is removed
from the prose.

## Claims

`[D1] grade::synthesis` An eligible pair's target — unclosed, so it is a
member of the open surface. Its own required derivation edge (pair 1 above)
is also eligible.
`derives-from:: [SEED1]`

`[E1] grade::synthesis` An eligible pair's deriving entry.
`derives-from:: [D1]`

`[D2] grade::proved` The deliberate excluded pair's target — corroborated,
so it is backed and can never appear in the open surface no matter how it is
reached.
`check:: true; at 3333333`

`[E2] grade::synthesis` The deliberate excluded pair's deriving entry —
anchoring here must NOT surface D2, because D2 fails open-surface membership
by itself, not by distance.
`derives-from:: [D2]`

`[SEED1] grade::synthesis` D1's own required derivation edge (the provenance
gate leaves no unclosed claim edge-free) — eligible in its own right (pair 4
above), not a bystander.
`derives-from:: [Q1]`

## Questions

`[Q1] grade::frontier` SEED1's own derivation target, open and unclosed —
keeps the fixture's provenance chain resolvable without pulling in anything
from outside this document.
`discharge:: SEED1's own required edge target; scores as pair 4 above`
`closer:: agent/test`
