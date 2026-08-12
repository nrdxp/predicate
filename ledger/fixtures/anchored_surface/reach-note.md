# Synthetic anchored-reachability fixture — bounded hops, mixed edges, filtering

`signer:: agent/test` · `at:: 0000000`

SYNTHETIC, exact by construction. It exercises the anchored-reachability view's
three hard properties at once: the two-hop bound, traversal over BOTH edge
species (provenance and closure), and the open-surface restriction applied to
what is RETURNED rather than to what is WALKED (a closed node may still be a
bridge).

Distances are all measured from A1.

- A1 (proved, corroborated) — the root. Backed, so it is never itself a
  member of the open surface, anchor or not.
- B1 — one provenance hop from A1. Unclosed: a member.
- C1 — one provenance hop from B1, two from A1. Unclosed: a member.
- D1 — one provenance hop from C1, THREE from A1. Must be excluded from
  A1's neighbourhood; included from C1's (C1 anchored directly, D1 is
  one hop).
- Q1 — closed by A1's closure edge, one hop from A1. Discharged, so NOT a
  member of the open surface despite the one-hop distance — the restriction
  the naive view in the-cap-is-binding log's C3 got wrong.
- H1 — one provenance hop from Q1, so TWO hops from A1 reached by CLOSURE
  then PROVENANCE. Q1 is excluded from the output but is not removed from the
  graph: H1 is still reachable through it. Open (frontier question): a
  member.
- X1 — a second, disconnected cluster. No edge to A1's component at all.
  Unclosed: a member, but only when named as its own anchor (or with no
  anchor at all, where recency governs).
- Y1 — one provenance hop from X1.
- Z1 — a fully disconnected, open, unclosed question. Reachable from no
  anchor in this fixture at any distance — the multi-anchor test's negative
  control.

## Claims

`[A1] grade::proved` The root evidence claim, corroborated by a check that ran.
`check:: true; at 0000000` `discharges:: [Q1]`

`[B1] grade::synthesis` One provenance hop from A1.
`derives-from:: [A1]`

`[C1] grade::synthesis` Two provenance hops from A1, one from B1.
`derives-from:: [B1]`

`[D1] grade::synthesis` Three provenance hops from A1 — excluded from A1's
two-hop neighbourhood; reachable only when C1 (or D1 itself) is the anchor.
`derives-from:: [C1]`

`[X1] grade::synthesis` Root of a second, disconnected cluster — no edge
reaches A1's component.
`derives-from:: [Q4]`

`[Y1] grade::synthesis` One provenance hop from X1.
`derives-from:: [X1]`

## Questions

`[Q1] grade::dispatchable` Closed by A1's discharge — must be excluded from
the open surface despite sitting one hop from A1.
`discharge:: closed in this fixture by A1's discharges edge` `closer:: agent/test`
`derives-from:: [H1]`

`[H1] grade::frontier` Reached from A1 only by passing THROUGH the closed Q1 —
one provenance hop from Q1, two edges from A1 in total.
`discharge:: exercises pass-through of a closed intermediate node` `closer:: agent/test`

`[Q4] grade::frontier` X1's own one-hop neighbour on the provenance side —
paired with X1/Y1 to keep the second cluster self-contained and open.
`discharge:: closes the second cluster's own frontier` `closer:: agent/test`

`[Z1] grade::frontier` Disconnected from every other entry in this fixture —
open, but reachable from no anchor here.
`discharge:: the negative control for reachability boundedness` `closer:: agent/test`
