# Pass-1 IBC — GRADED — the core ledger ENTRY contract and its fixtures

**This document is the authoritative boundary for pass 1, hand-graded under
the vocabulary it installs.** The YAML rendering (`ibc-pass1.yaml`, this
directory) is the FLOOR: it conforms to the current, unreformed
`ledger/contracts/worker_ibc.ncl` (validated: `nickel export
.scratch/typed-claims/ibc-pass1.yaml --apply-contract
.scratch/typed-claims/ibc-pass1-apply.ncl` → EXIT=0). The reformed shape
that could validate THIS document is pass 1's own deliverable applied to
`worker_ibc.ncl` in pass 2 — it cannot be its own prerequisite, so the
grading here is by hand, per the originating boundary's own standard. The
worker reads this document FIRST, then the YAML.

Signer of every node below: **the architect seat (agent)**, at first
authoring 2026-08-10. Checks were run against the WORKING TREE at session
time, not a commit — see finding V-3.

## Legend and the count

Marker grammar (exact tokens, machine-countable): every graded node carries
one `grade::<cell>` token — `grade::proved` (check RUN, named inline),
`grade::cited` (named witness, locator given), `grade::synthesis` (unbacked;
MUST carry `derives-from::`), `grade::dispatchable` / `grade::routed` /
`grade::frontier` / `grade::residual` (questions; each carries
`discharge::` and `closer::`). `grade::directive` is an OUT-OF-VOCABULARY
token — see finding V-1; directives carry `provenance::` instead of backing.

Reproduce the count:

```bash
# scoped to everything BEFORE §7 — the results section quotes its own output,
# so counting the whole file would make the published numbers self-referential
# and unreproducible:
sed -n '1,/^## 7/p' .scratch/typed-claims/ibc-pass1.md \
  | grep -oE 'grade::(proved|cited|synthesis|dispatchable|routed|frontier|residual|directive)' \
  | sort | uniq -c | sort -rn
# cross-check the total (catches malformed tokens the first grep would drop):
sed -n '1,/^## 7/p' .scratch/typed-claims/ibc-pass1.md | grep -o 'grade::' | wc -l
```

**Numbers live in exactly ONE place: §7**, which pastes the commands' live
output after the final edit. This legend teaches HOW to count and states
the identity the two commands must satisfy — full-token count + located
non-token mentions = bare-occurrence count, every term enumerated — but
deliberately carries no concrete numbers: a count stated in two places is
the stale-number defect this discipline exists to prevent, and this legend
committed exactly that once (caught by the second probe; §7 was right, the
legend's illustrative copy had gone stale across a revision).

---

## 1. Premises — graded claims about the world

- **P1.** The draft contract exists at
  `.scratch/typed-claims/draft-node-contract.ncl` and typechecks clean.
  `grade::proved` check:: `nickel typecheck
  .scratch/typed-claims/draft-node-contract.ncl; echo EXIT=$?` → EXIT=0,
  nickel-lang-cli 1.14.0, run 2026-08-10.
- **P2.** The second dimension is named `assertion` (values claim/question);
  `kind` is docket's axis and must not collide. Head-ruled.
  `grade::cited` source:: `.ledger/log/2026-08-10-docket-seam.md:27-38`
  (divergence 1, marked RESOLVED; witness: the head, via the recorded note).
- **P3.** `residual` is question-shaped by DERIVATION: the cell table is
  exhaustive over claims, all six inhabited cells name a cure, the two empty
  cells are refuted by the determination gate; no claim is ever open by
  theorem. `grade::cited` source::
  `.ledger/log/2026-08-10-typed-claims.md` (Q7 resolution) and
  `draft-node-contract.ncl:190-196` (the derivation restated in the draft's
  own comment).
- **P4.** The fixture-harness precedent is an expect-runner asserting exit
  code AND a right-reason keyword per red case, over pure-data YAML fixtures
  and an external apply shim. `grade::proved` check:: `sed -n '1,60p'
  ledger/gate/test_council.sh` — read 2026-08-10; the expect() function at
  :34-47 asserts both.
- **P5.** Bare Nickel enums reject the string forms YAML carries; the house
  fix is the value-restricted tag-or-string idiom. `grade::proved` check::
  `sed -n '20,33p' ledger/contracts/discipline.ncl` (the idiom + its
  rationale) and `ledger/contracts/deposit.ncl:49-64` (EvidenceMethod, same
  rationale) — both read 2026-08-10.
- **P6.** Git history is the Record; append-only needs no new contract
  machinery — editing a note is an append at the record level; only history
  rewriting forfeits it, and that is already barred. `grade::cited` source::
  `.ledger/log/2026-08-10-typed-claims.md` ([I1] restated — head
  correction); witness: the head, via the composer's recorded relay.
- **P7.** The fixtures directory convention is `ledger/fixtures/<topic>/`.
  `grade::proved` check:: `ls ledger/fixtures/council/` — run 2026-08-10.
- **P8.** `worker_ibc.ncl` is the unreformed shape: measured as a parallel
  structure (three free-text names for one backing concept, no unknowns
  class, no evidence species, no signer). `grade::cited` source::
  `.scratch/typed-claims/deposit-shapes-b.md:9-35` (measurement R1-R6 with
  per-line evidence).

## 2. Draft defects — graded claims about the draft

- **D-2 (defect).** The draft's `ProvenanceGate` is unscoped: it constrains
  every `backing='unclosed` node, questions included, so a `frontier`
  question (question ∧ unclosed, edge-free at birth) is REJECTED — making
  `frontier` unrecordable, the exact compression loss L2 that bit twice this
  pass. `grade::proved` check:: `sed -n '181,183p'
  .scratch/typed-claims/draft-node-contract.ncl` — the predicate tests only
  `n.backing != 'unclosed`, no assertion guard. The source gate is
  claim-scoped: `grade::cited` source::
  `.ledger/log/2026-08-10-typed-claims.md:86` — "unclosed claim ⟹ ≥1
  inbound derives-from edge" (carried in-repo; original in the
  factoring-trust typed-ledger note:129).
- **D-3 (defect).** The draft's Signer rule "name omitted only for
  'derived" is comment-only — no predicate enforces it; a prose rule
  without an evaluator inside the contract whose purpose is eliminating
  those. `grade::proved` check:: `sed -n '38,45p'
  .scratch/typed-claims/draft-node-contract.ncl` — `name | NonEmptyString |
  optional` with the rule in the comment; grep the draft for a predicate
  touching `signer` → none exists.
- **D-6 (defect).** `Backing`, `Assertion`, and `SignerKind` are bare enums
  (`[| ... |]`), which reject YAML string forms — every YAML fixture and
  every future YAML entry fails on arrival. The presence of bare enums:
  `grade::proved` check:: `grep -n "\[|"
  .scratch/typed-claims/draft-node-contract.ncl` → lines 38, 61, 66. The
  rejection BEHAVIOR — upgraded to a run per D-10 (it was previously
  grounded in P5's idiom comments, the class D-10 forbids):
  `grade::proved` check:: `backing: corroborated` (YAML) against
  `{ backing | [| 'corroborated, ... |] }` via `--apply-contract` →
  ENUM_EXIT=1, "contract broken by the value of `backing` / expected an
  enum" (nickel 1.14.0, exit captured before any pipe, 2026-08-10).

## 2b. The cure spec — pinned from the paper, the independent oracle for a4

The six expected `cure_for` outputs, pinned HERE so the acceptance test has
an external spec and never restates the implementation (a4). One claim:
this table is the paper's cell table, rows 1-6 verbatim in verdict and
cure. `grade::cited` source:: factoring-trust
`docs/paper/_06-cell-table.qmd`, table `#tbl-cells` — **an EXTERNAL
locator: that repository is not openable from this one.** Read by this
seat 2026-08-10; the six rows are reproduced below in full, so the worker
needs no access to the source to implement against it. (The paper's
"EALM", cited unexpanded in this repo's ledger notes, is *Endurance As
Logical Monotonicity* — `_03-theorem.qmd:5`.)

The installed `cure_for` MUST return exactly these strings (the test
hardcodes them; the labels compose T1/T2/T3 as the draft already does):

| determined | certifiable | monotone | expected return |
| :-- | :-- | :-- | :-- |
| yes | yes | yes | `none — verify` |
| yes | yes | no | `T3: a liveness holder (witness quorum or gossip), or restriction to "as of t", or an accepted expiry` |
| yes | no | yes | `T2: a voucher — an admitted judgement; or restriction to a decidable subclass` |
| yes | no | no | `T2+T3: a voucher, plus a freshness mechanism` |
| no | — | yes | `T1: witness of history — an admitted signer or attestor` |
| no | — | no | `T1+T3: an admitted signer, plus a freshness mechanism` |

These are the draft's phrasings, verified faithful to the paper's rows
(paper row 2: "liveness holder: a witness quorum or gossip protocol; or
restriction to 'as of t'; or an accepted expiry" — same content, draft
punctuation). Faithfulness claim: `grade::proved` check:: side-by-side
read of `draft-node-contract.ncl:112-127` against `_06-cell-table.qmd`
rows 1-6, 2026-08-10, this seat. Rows 7-8 have no cure row because they
are empty by theorem (P3) — `cure_for` never receives them from a
validated node (CertifiabilityFibered makes them unrepresentable).

## 2c. The predicate set is CLOSED — the carry-forward made explicit (c12)

The probe found the boundary's worst ambiguity: a2 exercised nine
predicates while the constraints named six, leaving "carry the rest
forward" as a pattern to infer. The rule is now stated (c12): **the
installed contract exports exactly nine predicates — the draft's set,
minus NoSelfVouch (D-4), plus SignerDesignates (D-3), with D-2's scoping
and D-6's enums applied.** The four below carry forward in LOGIC — their
comparison BODIES are re-idiomed per D-8, as are all seven tag-comparing
predicates. **Grade correction, recorded not hidden:** this section
previously said "carried forward UNCHANGED" at `grade::cited` — wrong, and
wrong at the worst spot: the confident grade discouraged exactly the halt
the reserved clause requires (the third probe's finding). The citations
below ground each predicate's LOGIC only; every body changes:

- **CorroborationBacked** (draft:169-171) — requires a check that WAS RUN
  on a corroborated claim. Matches the ruled definition ("`corroborated` —
  a re-runnable check, *run*"). `grade::cited` source:: draft:167-171 +
  `.ledger/log/2026-08-10-typed-claims.md:69-71`.
- **VouchBacked** (draft:174-175) — a vouched claim names its witness.
  Matches "`vouched` — a named admitted witness" (admission itself is the
  consumer's, per D-4). `grade::cited` source:: draft:174-175 + the same
  note :72-73.
- **QuestionRoutable** (draft:186-188) — a question carries discharge AND
  closer. Matches the ruled question-halves requirement. `grade::cited`
  source:: draft:185-188 + the note's taxonomy section.
- **NonMonotoneNamesCure** (draft:216-219) — a non-monotone claim names
  its T3 cure. Matches cell-table rows 2/4/6 (§2b) and the docket-seam
  promotion concern. `grade::cited` source:: draft:213-219 +
  `.ledger/log/2026-08-10-docket-seam.md:79-96`.

The closure itself — nine and no others, HALT on any delta — is a ruling:
`grade::synthesis` derives-from:: the probe's blocking finding (two
competent readings diverged); D-3/D-4 (the two deliberate set changes);
the fronted-dependency stakes (an incomplete contract that looks complete
against a numbered list is exactly what pass 2 would import).

## 3. Rulings — the boundary calls, graded as what they are

Each ruling is this seat's judgment: unbacked until ratified, carried with
its provenance per the provenance gate. **nrd's dispatch approval converts
each to `vouched` (witness: the head); until then they are syntheses, and
the record shows it.** That visibility is D-4 working on its own author.

- **D-1 (Call 1).** Axes stay inline on the node, REQUIRED on claims,
  forbidden on questions, no defaults. `grade::synthesis` derives-from::
  the opt-in defect ("enforcement-on-the-registered is not enforcement",
  `.ledger/log/2026-08-10-typed-claims.md` Finding 4); the docket-seam
  promotion gate needing axes at the crossing
  (`.ledger/log/2026-08-10-docket-seam.md:79-96`); W3 tagging-cost
  acknowledged and mitigated (fibering → usually two booleans; cure derived
  not authored).
- **D-2 (ruling).** Scope the provenance gate to claims. `grade::synthesis`
  derives-from:: D-2 (defect, §2) + P3.
- **D-3 (ruling).** Add `SignerDesignates`: kind ≠ 'derived ⟹ name
  present; kind = 'derived ⟹ name absent ∧ ≥1 inbound edge (the
  designation IS the edges). `grade::synthesis` derives-from:: D-3 (defect,
  §2) + P6 ([I1]: naming the party is the terminal move).
- **D-4 (Call 4).** `NoSelfVouch` leaves the contract ENTIRELY — both
  halves; a vouched node's shape obligation is `witness {name, at}` and
  nothing more; admission is the consumer's policy. `grade::synthesis`
  derives-from:: the mechanization's shape/Policy separation ("Policy is
  the consumer's admission rule … a relativity the classifier itself never
  resolves" — factoring-trust `Ceiling/Evidence.lean:30-38`, read by this
  seat; carried in `.ledger/log/2026-08-10-typed-claims.md`); the
  frame-invariant pen law (solo corpora are largely self-vouched "and the
  record shows it. A feature."); self-vouch detection as the flagship QUERY
  (typed-ledger note) — a query requires self-vouched nodes to be
  RECORDABLE.
- **D-5 (Call 2).** `cure_for` stays in the contract file as the single
  normative source of the cell-table mapping, STRIPPED of its "ill-formed"
  branch. `grade::synthesis` derives-from:: W2 single-record rule (two
  consumers each encoding the table = dual-maintenance at law level); the
  dead-branch fact `grade::proved` check:: `sed -n '112,127p'
  .scratch/typed-claims/draft-node-contract.ncl` — the branch duplicates
  `CertifiabilityFibered` (draft:207-211).
- **D-6 (ruling).** Backing/Assertion/SignerKind become value-restricted
  tag-or-string contracts. `grade::synthesis` derives-from:: D-6 (defect,
  §2) + P5.
- **Call 3 (fixture matrix).** One red per predicate with a right-reason
  token (both directions where bidirectional) + shape reds + nine greens
  minimum (every inhabited cell, residual question, self-vouched claim,
  derived-signer synthesis); red baseline via true-reds-against-the-draft
  for D-2/D-3/D-6 and mutation checks elsewhere. `grade::synthesis`
  derives-from:: P4 (the harness pattern); the greens-prove-reds-
  discriminate argument (a contract rejecting everything passes every red);
  one-shot skepticism applied to fixtures.
- **D-9 (the contract surface is LIFTED predicates — bare functions are not
  contracts and anonymous ones cannot satisfy c4).** Three behaviors,
  each `grade::proved` by this seat's runs 2026-08-10 (exit captured before
  any pipe; the fourth probe ran them independently first — two runs, one
  verdict each): (1) a bare `fun n => bool` under `std.contract.all_of` is
  NOT a valid contract — nickel 1.14.0 warns "plain functions as contracts
  are deprecated" then errors (BARE_EXIT=1); (2) `std.contract.
  from_predicate` under all_of fails with an anonymous "contract broken by
  a value" — no token, c4 unsatisfiable; (3) a `std.contract.custom`
  wrapper returning `'Error { message = "<Name> violated" }` surfaces the
  token under `--apply-contract` (LIFT_EXIT=1, token present). The RULING:
  keep every predicate as a bare boolean function (the batch-validation
  design stands), and derive its contract form through ONE generic lift —
  `asContract = fun name pred => std.contract.custom (fun _label value =>
  if pred value then 'Ok value else 'Error { message = "%{name}
  violated" })` — with `entry_apply.ncl` composing `std.contract.all_of`
  over the LIFTED nine. One logic definition, names carried by the lift,
  c4 satisfiable, house precedent honored. `grade::synthesis` derives-from::
  the three proved behaviors; the house idiom (`dag.ncl:125-127`
  DagNoConflict, `council.ncl` Constitution — both already
  custom-with-named-'Error); the c3/c4 pair this makes jointly satisfiable.
- **D-10 (behavioral claims are proved-by-run, or they are not in the
  boundary).** Rounds three and four each found exactly one structural
  defect, and both were untested assumptions about Nickel semantics
  (tag-vs-string comparison; predicate-application shape) — a CLASS, not a
  coincidence. The RULING, binding this boundary and applied to itself
  retroactively: any claim this boundary makes about language or tool
  behavior carries `grade::proved` with the demonstrating command — never
  `cited` to documentation or comments, never `synthesis`. Retroactive
  audit: D-6's rejection behavior was previously grounded in idiom
  COMMENTS (P5) plus greps of the draft — exactly the forbidden class; it
  is now proved by run (see D-6). Both D-8 and D-9 entered proved.
  `grade::synthesis` derives-from:: the two-defect pattern (rounds 3-4,
  one class); the cost asymmetry (each was catastrophic-silent in the
  artifact, one-line-cheap to test at authoring). Candidate for the
  /boundary discipline generally — routed to the head with q-shape-reform's
  channel; the fourth probe proposed it, this seat concurs after applying
  it to this boundary's own claims and finding one violation (D-6's
  grounding).
- **D-8 (predicate bodies must speak both forms).** Seven of the nine
  predicates tag-compare (`n.backing != 'corroborated`), and D-6 admits
  YAML strings — against `"corroborated"` the comparison is unconditionally
  true and the predicate short-circuits to PASS regardless of what it
  guards. The contract would typecheck, pass every fixture authored naively,
  and enforce nothing. Inertness fact: `grade::proved` check:: the third
  probe's repro, re-run by this seat 2026-08-10 — `string_equals_tag =
  false, predicate_verdict_should_be_false = true` (nickel 1.14.0; the
  composer verified independently first — two runs, one verdict). The
  RULING: every enum comparison inside a predicate body goes through ONE
  shared helper (`matches v 'tag "tag"` — the dual-comparison idiom of
  `discipline.ncl:27-33` factored to a single definition), never a bare
  tag compare. Normalizing inside the enum CONTRACT instead is REJECTED on
  a design fact: the predicates are deliberately exposed bare so the batch
  validator can collect every violation over raw YAML-parsed data —
  normalization at contract application never reaches them.
  `grade::synthesis` derives-from:: the inertness fact; the bare-predicate
  design rationale (draft:160-166); P5's idiom. Two consequences bind: the
  probe's repro becomes a permanent CANARY case in test_entry.sh (c13),
  and §2c's "carried forward unchanged" was WRONG — corrected there, the
  bad grade named.
- **D-7 (naming).** The contract's top-level record is **`Entry`**, file
  `ledger/contracts/entry.ncl` — never `Node`/`node.ncl`. The collision is
  fact: `dag.ncl:44` already exports `Node` meaning a campaign DAG node,
  and the gate-set tooling uses "node" the same way, so "the ledger node
  contract" misreads as DAG machinery to anyone outside this pass —
  `grade::proved` check:: `sed -n '44,48p' ledger/contracts/dag.ncl` (the
  Node record) and `grep -riE '\bEntry\b' ledger/ --include='*.ncl'` → no
  existing Entry contract, the name is free; both run 2026-08-10. The
  choice of `Entry` specifically: `grade::synthesis` derives-from:: the
  paper's own vocabulary ("a record is a finite, append-only sequence of
  entries"); the probe's candidate, verified rather than adopted on
  relay; the `kind`/`assertion` collision one level up (P2) — the same
  defect class, cheapest to fix before nine contracts import the name.

## 4. Directives — the normative content, graded by provenance

The goal, non-goals, constraints c1-c11, and acceptance a1-a8 live in
**`ibc-pass1.yaml` only** (single source; duplicating their text here would
be the two-records failure this discipline exists to end). They are
DIRECTIVES: they assert no truth-value and ask nothing — no cell of the
vocabulary fits them (finding V-1). Each is graded here by id, by
provenance:

- c2, c3, c4, c11 `grade::directive` provenance:: standing law (the commit
  gate, data-is-YAML house rule, the harness pattern P4) — cited grounds,
  not new rulings.
- c1 (surface), and the destination paths `grade::directive` provenance::
  this seat's boundary-design authority ('single assent), following the
  P7 convention.
- c5, c6, c7, c8, c9, c10 `grade::directive` provenance:: rulings D-2, D-4,
  D-3, D-5, D-1, D-6 respectively (§3) — each inherits its ruling's
  synthesis status and converts to head-backed on dispatch approval.
- c12 `grade::directive` provenance:: the closure ruling (§2c) — inherits
  its synthesis status; converts with the rest on dispatch approval.
- c13 `grade::directive` provenance:: ruling D-8 (§3) — the no-inert-
  predicates rule and its canary; inherits D-8's synthesis status.
- c14 `grade::directive` provenance:: rulings D-9 and D-10 (§3) — the
  spike-first rule: the worker reproduces the three proved behaviors in
  isolation BEFORE writing entry.ncl, so every load-bearing Nickel
  assumption is demonstrated in its own environment at planning time, not
  discovered at export time.
- a1-a8 `grade::directive` provenance:: mechanical renderings of c2-c12
  plus the delivery rule (dispatched.ncl: a report is DELIVERED, not
  written); a4's oracle is §2b, a5's schema is stated in the YAML.

## 5. Open questions — each with both halves

- **q-store.** Corpus-level referential integrity (unique ids, resolving
  edges) across files: Nickel store contract over an aggregate instance, or
  validator-level check? `grade::dispatchable` discharge:: the worker
  builds one of the two inside the delegated set and records why; the
  choice is checkable at reconcile against the delegated-set bounds.
  closer:: the architect seat, at pass-1 reconcile.
- **q-probe.** Has the comprehension probe run against this IBC?
  `grade::routed` discharge:: a zero-context cheap-tier dry run producing a
  plan + unanswerable-questions list, iterated to ~0. closer:: the
  composer (dispatches the probe before the worker).
- **q-commit.** Does the pass-1 dispatch carry commit authorization? No
  campaign DAG is active; the rail requires an active DAG or an explicit
  human instruction consumed at the task boundary. `grade::routed`
  discharge:: the dispatch quotes the head's authorization verbatim.
  closer:: the composer relaying nrd.
- **q-shape-reform.** When does the grading move from hand-marked markdown
  into the contract shape itself, collapsing the md/YAML split this document
  carries? `grade::routed` discharge:: pass 2 reforms `worker_ibc.ncl`
  against the pass-1 entry contract; the pass-2 boundary must carry this as
  a requirement. closer:: the architect seat, at pass-2 boundary
  authoring; nrd ratifies.

## 6. Vocabulary findings — the live test, reported not forced

- **V-1 — directives fit no cell.** A boundary document is mostly normative
  content: goals, constraints, acceptance criteria. These assert no
  truth-value (not claims) and have no discharge condition (not questions).
  The assertion dimension {claim, question} cannot express them, and forcing
  them into `synthesis` would flood the unclosed count with items that are
  not epistemically open — they are COMMANDS, closed by authority, not
  evidence. I marked them `grade::directive` with `provenance::` instead of
  forcing. Implication for pass 2: reforming `worker_ibc.ncl` under the
  entry contract will hit this immediately — either the assertion dimension
  gains a third value (with its own backing analogue: the issuing
  authority), or boundary documents stay outside the claim graph and only
  their premises and defect-claims enter it. Routed with q-shape-reform;
  the ruling is nrd's. `grade::synthesis` derives-from:: the definitional
  reads (P2, P3) + this document's own grading exercise as the instance.
- **V-2 — self-signed syntheses graded cleanly (positive finding).** This
  seat's rulings are its own unbacked judgments — the exact self-vouch
  shape D-4 addresses. The vocabulary handled it without strain: synthesis
  + derives-from + a named ratification path that converts the grade. The
  visibility-not-illegality design (D-4) is corroborated by its own
  author's deposit. `grade::proved` check:: §3 of this document — every
  ruling carries the marker and its edges; the count below shows the
  unclosed mass concentrated exactly there.
- **V-3 — the `at` anchor is undefined against a dirty tree.** Every check
  in §1-§2 ran against the WORKING TREE, which has no commit id — but the
  entry contract's `Check.at` and `Witness.at` require a `CommitRef`. Real
  grading frequently happens against uncommitted state; the vocabulary as
  drafted cannot record where such a check ran, and rounding to "the
  nearest commit" would claim a state the check did not test.
  `grade::proved` check:: `git status --porcelain | head` → non-empty
  (dirty tree), 2026-08-10; `grep -n "at | CommitRef"
  .scratch/typed-claims/draft-node-contract.ncl` → Check:76, Witness:87.
  Disposition: NOT a pass-1 contract change (fixtures use synthetic
  hashes legitimately); recorded for the pass-2/3 boundary and the eventual
  gate design. `grade::frontier` discharge:: none stated yet — candidate
  shapes exist (tree-hash via `git stash create` / `git write-tree`, or
  an explicit `dirty: true` marker) but none is ruled. closer:: the
  architect seat proposes at pass-2 authoring; nrd rules.

- **V-4 — grading makes errors checkable, not impossible; state the limit.**
  The D-8 defect was findable ONLY because §2c stated the carry-forward
  claim explicitly with a grade a probe could test — an ungraded IBC would
  have carried the same landmine with nothing to test against. But the
  grading did not PREVENT the error: a `cited` grade was simply wrong. The
  discipline's honest claim is auditability, never infallibility — the
  tagger is still the agent whose calibration is in question (W3), and this
  document is now its own second instance (the stale legend was the first).
  Route: this limit belongs in the discipline's own documentation when
  pass 2/3 write it, stated at exactly this strength. `grade::synthesis`
  derives-from:: the D-8 episode (this document); W3
  (factoring-trust typed-ledger note, carried in
  `.ledger/log/2026-08-10-typed-claims.md`); the composer's third-probe
  observation, concurred with rather than adopted on relay.

## 7. Unclosed fraction — computed, not estimated

Live output of the legend's two scoped commands, run 2026-08-10 after the
final edit of everything above this section:

```
     17 grade::proved
     15 grade::synthesis
     12 grade::cited
      9 grade::directive
      4 grade::routed
      2 grade::frontier
      2 grade::dispatchable
      1 grade::residual
---
65
```

Reconciliation (every occurrence accounted for, none silently dropped):
bare occurrences = full tokens + 3 non-tokens, each located by
`sed -n '1,/^## 7/p' … | grep -Pn 'grade::(?!(proved|cited|synthesis|dispatchable|routed|frontier|residual|directive)\b)'`
→ lines 21, 35, 38: the grammar's `grade::<cell>` and the two command
lines, all in the legend — locator re-verified live against this revision.
(Locator CORRECTED this round: the previous suffix-filter form read line
35's command text as ending in `directive` and located only two of the
three — the count was right, the "locates all three" claim was not. Fourth
probe's find; third member of the self-referential-accounting class, after
the stale legend and the retracted grade. The lookahead form above has no
suffix blind spot.) Of the 62 full tokens, 8 are the legend's one-per-cell
definitions and 3 are in-prose MENTIONS — V-1's `grade::directive`, §2c's
`grade::cited` (the retraction naming the grade it retracts), and D-10's
`grade::proved` (the rule naming the grade it mandates; a rule about
grades must say which) — leaving **51 graded nodes** (62 − 8 − 3):

| kind | cells | nodes |
| :-- | :-- | --: |
| claims | proved 15 · cited 10 · synthesis 14 | 39 |
| questions | dispatchable 1 · routed 3 · frontier 1 · residual 0 | 5 |
| directives (out-of-vocabulary, V-1) | — | 7 |

**Unclosed fraction = (synthesis 14 + frontier 1) / (claims 39 + questions
5) = 15/44 ≈ 34%.** Directives are excluded per V-1 — they are closed by
authority, not evidence, and counting them either way would distort the
epistemic number.

Reading: twelve of the fourteen syntheses are the rulings awaiting nrd's
ratification (D-1..D-10, the fixture matrix, the c12 closure) — exactly
where a boundary's openness should sit at dispatch time; approval converts
them to `vouched` and drops the fraction to 3/44 (V-1, V-4, and the V-3
frontier remain, correctly, open). The premises, defect claims, the cure
spec, and the carry-forward LOGIC dispositions are closed — and after
D-10's retroactive audit, every behavioral claim in this boundary is
proved by a run with its exit captured before any pipe.
