# Pass-2b IBC — GRADED — council.ncl extends the core, under settled doctrine

**Authoritative graded boundary for pass 2b — the last reform, the riskiest
contract, authored against the RATIFIED pen law.** Floor: `ibc-pass2b.yaml`,
reformed shape, validated EXIT=0 via the pass-1 shim over the live
worker_ibc.ncl. Signer of every node: the architect seat (agent),
2026-08-11. One cold probe round; dispatches unless a BOUNDARY defect.

Count commands (numbers only in §7):

```bash
sed -n '1,/^## 7/p' .scratch/typed-claims/ibc-pass2b.md \
  | grep -oE 'grade::(proved|cited|synthesis|dispatchable|routed|frontier|residual|directive)' \
  | sort | uniq -c | sort -rn
sed -n '1,/^## 7/p' .scratch/typed-claims/ibc-pass2b.md | grep -o 'grade::' | wc -l
```

---

## 1. Premises

- **R1.** The prerequisites are LANDED: `69c7cc2` (unattributed mode, per
  this seat's ruling), `b5107a8` (recorder gate — .ledger now validates
  records at commit time), `df35300` (ceiling frozen; plugin default 0,
  the 22 in `.ledger/config.sh` — the worker's override was correct and
  is hereby ratified: hardcoding 22 into shared machinery would
  grandfather free slots into every fresh recorder), and in the ledger
  subrepo `25ffa7b` (22 records migrated, both fields RECOVERED not
  stamped) + `add81b2`. `grade::proved` check:: `git log --oneline -6`
  in both repos, 2026-08-11.
- **R2.** `council.ncl` is UNREFORMED: zero `import "entry.ncl"`;
  `Decision = {id, type, assent, barred, verdict, grounding}` at :86-93 —
  no proposer, no at, no subject, grounding a bare NonEmptyString.
  `grade::proved` check:: `grep -c 'import "entry.ncl"'
  ledger/contracts/council.ncl` → 0; sed read of :86-93.
- **R3.** Existing coverage: NINE fixture files under
  `ledger/fixtures/council/` (the dispatch said eight; the count is
  nine — precision per house discipline), `test_council.sh` EXIT=0 at
  this seat. `grade::proved` check:: `ls | wc -l`; suite run.
- **R4.** The Evidence ripple is PROVED, not to be rediscovered:
  `procedure.ncl`, `discovery.ncl`, `refine_procedure.ncl` apply
  `deposit.Evidence`; `discovery.ncl`'s destructure makes deposit.ncl's
  NonEmptyString alias re-export LOAD-BEARING; council fixtures embed
  deposits, so the Decision reform touches fixture-embedded Evidence
  shapes. `grade::cited` source:: pass-2 worker deposit (boundary
  feedback 5) + pass-2 reconcile (item 4, encoded as this premise).
- **R5.** `docs/deposits.md` references the home (1 hit) but its body
  still describes the PRE-reform Evidence shape (no signer, no species
  anchors) — F-B, unrewritten by design. `grade::proved` check::
  `grep -c entries.md docs/deposits.md` → 1; F-B's pass-3 finding cited
  for the body staleness.

## 2. Rulings (G-series)

- **G-1 (the Decision reform).** Decision gains `proposer | Signer` (who
  brought it) and `at | CommitRef` (the state decided against);
  `grounding` becomes SPECIES-AWARE: it names either a run check (core
  Check: command, ran, at) or an admitted witness (core Witness: name,
  at) — the E-5 requirement landing where it was deferred. The bare
  string dies; "never empty" becomes "never speciesless."
  `grade::synthesis` derives-from:: E-5; the pass-2 reform table's
  council row (pre-split); the core shapes at entry.ncl.
- **G-2 (Q-d CLOSED — subject-modeling, minimal and shape-determined).**
  Decision gains `subject | seat-id | optional` — whose CONDUCT the
  decision is about. REQUIRED on `'bar` (a bar always has a subject);
  absent on decisions not about a party. The admission check this
  enables, landing in council.ncl as the council's own Policy (per D-4,
  policy in the consumer): **NoSelfAssent — `subject ∉ assent`**; the
  subject's assent on a decision about its own conduct is void, exactly
  as a barred seat's is. The GENERAL "is this target the signer's own
  conduct" beyond an explicit subject stays a review matter — no
  fake decidability. `grade::synthesis` derives-from:: Q-d (deferred
  from E-5); D-4's shape/policy line; the barring machinery's existing
  void-semantics (no_barred) as the pattern.
- **G-3 (preserve the machinery WHOLE — the split's reason).**
  Anti-incoherence, ungoverned, no-barred, anti-unilateral,
  merge-consent, head-ratification: every existing check keeps a red
  that fails for ITS OWN reason; the nine existing fixtures pass or
  their updates carry recorded rationale in the deposit (fixtures embed
  deposits — R4 — so updates are EXPECTED, and each is justified, never
  silent). `council_consent.sh` keeps reducing to the contract. **Scope
  of "WHOLE", stated so the apparent G-1 collision closes: it binds the
  six guard FUNCTIONS, not the Decision record SHAPE** — none of the six
  inspects `grounding` (probe-enumerated, adopted), so the shape reform
  and the preserve obligation touch disjoint surfaces. Known cost,
  stated: all EIGHT decision-bearing fixtures carry bare-string
  grounding and none typechecks under G-1 — every one is rewritten, each
  with its rationale row.
  `grade::synthesis` derives-from:: the split decision's grounds; the
  reduce-to-law header of council_consent.sh; the probe's guard/field
  enumeration and fixture grep (adopted).
- **G-4 (the maintainer's price — constructional enumeration, with the
  counting unit DEFINED FOR THIS FILE).** council.ncl carries no
  `asContract` and no `lifted` — its law is hand-rolled if/else chains
  (probe-verified, adopted). The constructional rule is therefore stated
  idiom-independently, which is what it always meant: **the counting
  unit is the VERDICT-PRODUCING CONDITIONAL — every branch that can
  yield a distinct violation or 'Error, enumerated by WALKING the
  reformed contract text, each row carrying its file:line.** That covers
  the existing chain (each named guard's branch), the Constitution's
  intrinsic checks, and the two NEW checks in whichever idiom they land
  (the lifted-vs-intrinsic choice stays delegated; the COUNT is
  idiom-blind). Derivation aid, not the definition:
  `grep -n "'Error\|else if" ledger/contracts/council.ncl` over the
  reformed file approximates the site list the walk must reconcile
  against. Joint rows keep the kind column; duplicates are CUT.
  `grade::cited` source:: the maintainer's consent condition (composer
  relay, pass-2 gate); the joint-row ruling; the probe's zero-hit greps
  (adopted as fact).
- **G-8 (the violation-chain ordering for the new checks — RULED, since
  the chain's whole design is most-specific-first and an unspecified
  slot re-opens the attribution problem pass 2 closed).** The order:
  **bar-without-subject → self-assent → no_barred → merge-consent →
  class checks.** Grounds: bar-without-subject is the most specific (it
  fires only on 'bar and is the structural PRECONDITION of evaluating
  self-assent on a bar — no subject, nothing to void); self-assent
  precedes no_barred because the subject's void is INTRINSIC to the
  decision's own content while barring is EXTRINSIC state, and a seat
  both subject and barred should surface the self-assent token — the
  more informative defect, naming the conduct conflict. CONSEQUENCE,
  mandatory not nicety: one two-violation ORDERING FIXTURE (a decision
  whose subject is also barred) asserting the self-assent token
  surfaces — the ordering becomes a tested property, per the pass-2
  all_of lesson. `grade::synthesis` derives-from:: the chain's
  most-specific-first design (council.ncl's violation ordering,
  probe-enumerated); the pass-2 attribution round; the intrinsic-
  before-extrinsic distinction.
- **G-5 (pairing + vacuity, standing law here).** Every
  negative-property obligation carries BOTH enumerated checks (each with
  a pre-edit red baseline — a negative check green before any edit
  verifies nothing) AND an unbounded sweep over the property class.
  `grade::cited` source:: F-A (pass-3 reconcile — the seventh sole-pen
  instance only the sweep found); the h7 vacuity rule.
- **G-6 (F-B lands here).** `docs/deposits.md` rewritten against the
  reformed `deposit.ncl` — species split, signer, anchors — referencing
  the home for vocabulary, per the satellites-reference rule.
  `grade::synthesis` derives-from:: F-B (pass-3 reconcile routing).
- **G-7 (the escalation rule — answered now so 2b is not reopened).**
  The head's candidate rule (the type decides autonomy: dispatchable
  never escalates; routed escalates only when its closer is the human;
  frontier wants a proposed discharge before permission; residual is
  named, never worked) **does NOT change council.ncl's shape.** It reads
  ENTRY fields (backing, closer) — routing policy over questions, living
  in the composer's discipline and eventually a gate, not in the
  constitution contract, which governs DECISIONS. The one shape
  dependency it has is on `entry.ncl`'s `closer` field — free text
  today; a mechanical rule wants it resolvable to a designation. That is
  CORE territory, filed for the escalation design itself, not smuggled
  into 2b. `grade::synthesis` derives-from:: the closer field's current
  type (entry.ncl, proved in pass 1); the decisions-vs-questions object
  split; D-4's policy-in-consumer line.

## 3. Open questions

- **Qa.** Do any of the nine fixture updates change what a scenario
  TESTS (vs merely re-shaping embedded deposits)? `grade::routed`
  discharge:: per-fixture rationale in the deposit; the maintainer
  judges at his gate. closer:: lead-maintainer.
- **Qb.** Does the closer-typing question (G-7) warrant a core amendment
  when the escalation rule is designed? `grade::routed` discharge:: the
  escalation design's own boundary, when nrd commissions it. closer::
  nrd.

## 4. Directives — in the YAML, graded by provenance

Constraints j1-j10 and acceptance e1-e7 live in `ibc-pass2b.yaml`.
- j1 (surface), j10 (frozen everything-else) `grade::directive`
  provenance:: this seat; R1-R2.
- j2-j4 (Decision reform, NoSelfAssent, machinery preserved)
  `grade::directive` provenance:: G-1..G-3.
- j5 (constructional mutation), j6 (pairing+vacuity) `grade::directive`
  provenance:: G-4, G-5 — j5 is the MAINTAINER's consent condition,
  carried verbatim.
- j7 (F-B), j8 (data-YAML/tag-or-string), j9 (commit discipline)
  `grade::directive` provenance:: G-6; standing law.
- e1-e7 `grade::directive` provenance:: mechanical renderings.

## 7. Unclosed fraction — computed, not estimated

```
      6 grade::synthesis
      5 grade::directive
      4 grade::proved
      3 grade::cited
      2 grade::routed
---
22
```

Reconciliation: 20 full tokens + 2 non-tokens (the inline command block,
located by the lookahead form at lines 13 and 15) = 22 bare. No legend
restatement, no mentions: **20 graded nodes** (G-8, the ordering ruling,
added one synthesis in the probe-response revision):

| kind | cells | nodes |
| :-- | :-- | --: |
| claims | proved 4 · cited 3 · synthesis 6 | 13 |
| questions | routed 2 | 2 |
| directives | — | 5 |

**Unclosed fraction = 6/15 = 40%.** All six syntheses are the G-rulings,
converting on dispatch approval → 0/15. No frontier, no residual: 2b
inherits a settled law, proved premises, and every lesson the sequence
recorded — the fraction is entirely the rulings awaiting their sanction.
