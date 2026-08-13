# Synthetic directive-transit fixture, hand-scored

`signer:: agent/test` · `at:: 0000000`

SYNTHETIC, exact by construction. Pins node/walk-directives: `Dv1` is a
directive-graded node with no depends/because/discharges/supersedes of its
own (a directive closes by authority, not derivation — entry.ncl's own
comment on why), reachable only through the entries that cite it.

- `M1`, `M2` — both unclosed claims, each deriving from `Dv1` (a corpus-
  tagged provenance edge, resolving against the widened entries-or-
  directives id space). Neither derives from the other, so the ONLY path
  between them is through `Dv1` — the fixture's control for two-hop
  transit.
- `N1` (proved, corroborated) / `N2` / `N3` — an ordinary derivation chain
  carrying no directive at all, included so the backed-exclusion self-check
  below has a genuine backed-exclusion pair (N2 deriving from N1) alongside
  a genuine eligible one (N3 deriving from N2), to contrast against the
  directive-targeted pairs.

## Reachability golden

- anchor=`Dv1` -> `{M1, M2}`: both cite `Dv1`, so both sit at distance 1;
  `Dv1` itself is never a member (no assertion/backing axis to satisfy
  open-surface membership at all — see [A4] in ruling-hooks-boundary.md,
  which scopes the emitted text to "questions and unclosed claims").
- anchor=`M1` -> `{M1, M2}`: `M1` at distance 0, `Dv1` at distance 1
  (excluded from output, same reason as above), `M2` at distance 2 — reached
  ONLY by transiting `Dv1`, since `M1` and `M2` share no other edge.

## Backed-exclusion self-check golden

Four provenance pairs total, in extraction order:

1. `M1` -> `Dv1` — target is a DIRECTIVE, not a claim or question. Excluded
   from this metric entirely (neither counted as excluded nor eligible): a
   directive carries no backed/unbacked state, so folding it in as "backed"
   would misreport why it can never surface.
2. `M2` -> `Dv1` — same as pair 1.
3. `N2` -> `N1` — `N1` is CORROBORATED (proved): backed, so genuinely
   excluded — the metric's actual domain.
4. `N3` -> `N2` — `N2` is unclosed: genuinely eligible.

Golden: the reported ratio is **1/2** — pairs 1 and 2 do not appear in
either the numerator or the denominator; only pairs 3 and 4 (the non-
directive-targeted pairs) are scored. A denominator of 4 would mean the two
directive-targeted pairs were folded in as if backed — the exact miscount
this fixture exists to catch.

## Claims

`[M1] grade::synthesis` One provenance hop from Dv1; shares no other edge
with M2, so any path between them must transit the directive.
`derives-from:: [Dv1]`

`[M2] grade::synthesis` One provenance hop from Dv1, symmetric to M1.
`derives-from:: [Dv1]`

`[N1] grade::proved` The ordinary chain's backed root — corroborated, so it
can never appear in the open surface regardless of distance.
`check:: true; at 0000000`

`[N2] grade::synthesis` Derives from the backed N1 — this pair is the
metric's genuine excluded case.
`derives-from:: [N1]`

`[N3] grade::synthesis` Derives from the unclosed N2 — this pair is the
metric's genuine eligible case.
`derives-from:: [N2]`

## Directives

`[Dv1] grade::directive` A directive with no derivation of its own, cited by
both M1 and M2 — the fixture's transit node.
`provenance:: architect ruling on this node's boundary`
