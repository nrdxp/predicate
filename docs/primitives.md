# Cross-Cutting Primitives

> New to predicate? Read the Orientation in
> [`predicate-architecture.md`](predicate-architecture.md) first — it defines the
> vocabulary (*walk*, *IBC*, *Nickel*, *deposit*, *harness*, the *Verification
> Dual*) this document uses.

Five primitives underlie predicate's procedure contracts, conditioning layer, and
discovery sub-procedure. They are cross-cutting — every major mechanism composes
on them. This document specifies each: what it is, why it exists, what it
guarantees, and where those guarantees are enforced.

Two terms recur throughout. **F-REQ** ("fixed required-set") is the property that
a procedure's required step-set lives *upstream* of the walk and cannot be
shrunk by the walk that runs it — the walk supplies deposits, never authors the
set that judges it. The **enforcement** column in each invariant table marks
**(S)** for a *symbolic* path — a deterministic Nickel contract or shell gate that
fails on violation — and **(A)** for the *adversarial* path — a review gate where
no machine evaluator can exist (see the Verification Dual in the Orientation).

---

## P-GROUND — the deposit substrate

**Purpose.** Every other primitive issues *deposits* — structured footprint records
written by a procedure step into the active instance. P-GROUND specifies what a
deposit is, how it is stored, and how deposits cross-reference one another. Without
it, inter-primitive composition is prose coordination.

**Model.** A deposit is a record:

```
{ id     | String        # unique identifier for this deposit
, step   | String        # which procedure step produced it
, evidence | NES         # non-empty string: the primary reviewer-checkable claim
, cites  | Array Path    # resolved paths the claim rests on
, refs   | Array DepositRef  # typed pointers to other deposits by id
}
```

A `DepositRef` is a typed pointer to another deposit by `id` — the mechanism that
lets one primitive's selection bind to another's discovery footprint. Provenance is
*composed via refs*, not asserted as prose.

- `cites` resolve to real paths (the cite-resolution gate).
- `refs` resolve to real deposit ids in the same instance (referential integrity,
  same pattern as `dag.ncl`'s id-uniqueness check).

**Invariants.**

| id | Invariant | Enforcement |
| :--- | :--- | :--- |
| I-G1 | Every deposit has a non-empty `id` and `evidence`; ids are unique within the store | structural — `ledger/contracts/deposit.ncl` (`DepositStore`) |
| I-G2 | Every `cite` resolves to a real path; every `ref` resolves to a real deposit id in the instance | structural — referential-integrity contract |
| I-G3 | The deposit's adequacy (is the evidence real, not vacuous?) | adversarial review |

**The two-purpose principle.** A deposit schema serves two purposes simultaneously:

1. *Formal gate* — did the agent fill it in (non-empty, well-typed, contract-
   compliant), or is it empty/maltyped?
2. *Reviewer substrate* — a machine-checked scaffold that makes the adversarial
   reviewer's job tractable: "the checks passed, but is what it filled in
   substantive, or lazy?"

Design criterion: a good deposit schema is the reviewer's checklist, formalized.
Decompose the deposit into exactly the sub-claims a reviewer would check anyway;
the machine verifies each is present + well-typed, the reviewer judges each one's
substance. A single free-text `justification` field fails both layers (machine
check is trivially "non-empty"; reviewer gets a blank page). Structured sub-claims
with evidence/cites/refs give both grip.

**Record-keeping substrates.** Deposits live in distinct locations with distinct
roles:

| Substrate | Role | Character |
| :--- | :--- | :--- |
| `.scratch/` | Exhaustive working detail; coherent context being built | Ephemeral; sometimes drafted for promotion |
| `.ledger/log/` | Linked trail of decisions, pivots, adjustments — a zettelkasten | Curated, linked, NOT exhaustive |
| `docs/` | Promoted durable artifacts | Permanent |
| `context_map.ncl`, `worker_ibc.ncl`, etc. | The live typed deposits (P-GROUND instances) | The formal substrate |

**Promotion.** Promotion is a combinator `promote(from, to)` — not two fixed
workflows. The destination is routed by the artifact's purpose:
- needed to reconstruct how/why but not general documentation → ledger zettelkasten;
- durable architecture or spec useful to a stranger → `docs/`;
- cross-cases: scratch → ledger, scratch → docs, ledger → docs.

An artifact is *structurally ready* for promotion when it conforms to its
destination's contract (a draft IBC passes `worker_ibc.ncl`; a DAG exports; this
document passes the zero-context sensibility read). Whether it is *worth promoting*
is judgment, closed by review.

**Zero-context read.** The quality test for any promotion to `docs/` is a stranger
who has never seen the internal work: does the artifact make sense in isolation?
Strip every reference only meaningful in-session; make explicit every assumption
a reader cannot reconstruct. The over-strip guard: never strip load-bearing
rationale. Test: does a stranger with the stated purpose need this to understand or
use the artifact? Yes → keep and make explicit. "Merely discussed" → strip.

Verified at: `ledger/contracts/deposit.ncl`.

---

## P-ARSENAL — capability-class selection

**Purpose.** Make the selection-rule meta-pattern a first-class, checkable
primitive: select the context-appropriate member of a capability *class*. Subsumes
tools, skills, evaluators, harness surfaces, and walker tiers.

**Model.** A capability class:

```
{ name    | String
, bias    | [| 'strongest, 'cheapest_sufficient |]
, members | Array String
, open    | Bool
}
```

`bias = 'strongest` where a miss is costly (evaluator, review); `bias =
'cheapest_sufficient` where finding the target bounds the cost (search, walker
tier).

The **arsenal registry** (`ledger/contracts/arsenal_registry.ncl`) is an upstream,
human-approved artifact — not self-declared by the walk. A `chosen` member outside
the gated registry fails. This is the same un-self-authored property as F-REQ:
the walk authors instances, never the sets that judge it.

**Shipped classes:**

| Class | Bias | Member ordering |
| :--- | :--- | :--- |
| `search` | cheapest-sufficient | keyword < regex < fuzzy < semantic |
| `evaluator` | strongest | linter < example-test < property-test < type < proof + review-floor |
| `review` | strongest | self-audit < single-decorrelated < multi-panel |
| `conditioning-surface` | strongest | prepend < rules-file < system-prompt |
| `walker-tier` | cheapest-sufficient | — |
| `discovery`, `prior-art`, `formal-modeling` | cheapest-sufficient | — |

**Selection procedure:** identify class → run the DISCOVERY sub-procedure's
`outward-environment` step to enumerate available members → select per `bias` →
degrade gracefully → deposit a `Selection` with a `ref` (P-GROUND) to that
DISCOVERY footprint. DISCOVERY is the shared sub-procedure specified in
[`predicate-architecture.md`](predicate-architecture.md) (§DISCOVERY).

**Invariants.**

| id | Invariant | Enforcement |
| :--- | :--- | :--- |
| I-A1 | Every governed decision deposits a `Selection` | presence — `ledger/contracts/procedure.ncl` |
| I-A2 | `chosen ∈ class.members` of the gated upstream registry (incl. human-approved extensions); `chosen ∈ available` | structural — registry gating bites because the registry is upstream, not self-authored |
| I-A3 | `available` is bound by `ref` to a deposited DISCOVERY `outward-environment` footprint | structural — via P-GROUND referential integrity |
| I-A4 | A non-top `chosen` carries a `ref` to the discovery footprint showing higher members absent | structural presence of the ref; whether the unavailability claim is true → review |
| I-A5 | Was the selection apt? | adversarial review |

**Termination of the selection regress.** P-ARSENAL selects evaluators, including
the `review` member that checks P-ARSENAL deposits — a potential infinite regress.
It terminates by doctrine: the `review` class has a fixed floor — decorrelated,
context-free reviewers — and reviewer-selection adequacy is not further reviewed.
The buck stops at human escalation — in the Verification Dual, human review is the
escalation-only slot.

**Instances.** Harness injection (`conditioning-surface`), discovery search
(`search`), the evaluator hierarchy (`evaluator`) are all instances of P-ARSENAL.
See `ledger/contracts/arsenal_registry.ncl`.

---

## P-COMPOSE — skill composition

**Purpose.** Each skill's innermost state machine is its procedure contract: its
states are the checkable steps, and a step may invoke a shared sub-procedure by
class (via P-ARSENAL). P-COMPOSE provides the general combinator that every skill
inherits.

**The combinator:**

```
procedure(skill) = core-steps
                 ∘ skill-specific-required-steps
                 ∘ sub-procedure-refs
                 ∘ output-contract
```

Prove the combinator's properties once, abstractly — footprint-presence +
required-upstream + altitude — and every skill inherits them by supplying only its
required-step set. Reasoning about each skill's machine individually would mean no
abstraction; the combinator is the abstraction.

**Model.** Each skill has an innermost state machine with `{ states, transitions,
guards }`. A state is either:

- a `leaf` — deposits `evidence + cites`, OR
- an `invoke` — calls a shared sub-procedure by class.

A state that does local work AND invokes is split into two states. The XOR holds
per state: mixing the two in one state hides what the machine is doing.

The **shared-sub-procedure registry** (`ledger/contracts/sub_procedures.ncl`) is
upstream and gated — same property as the arsenal registry. `invoke.class ∈
sub_procedures` or the export fails.

**Invariants.**

| id | Invariant | Enforcement |
| :--- | :--- | :--- |
| I-C1 | Required-step set pinned upstream (F-REQ); un-shrinkable | structural — complete_for probe |
| I-C2 | An `invoke` deposits a `ref` to the sub-procedure's footprint | structural — via P-GROUND |
| I-C3 | `invoke.class ∈ sub_procedures` (gated upstream registry) | structural — registry bites |
| I-C4 | Altitude: only skeleton + seams gated; creative interior stays prose | (A) over-formalization review |

**The promotion pass.** A concern emphasized in one skill but actually universal
lifts out of that skill into the combinator core. Canonical example: adversarial
review is emphasized in `/refine` but is a premise of the whole system — it lifts
to the core-steps so every procedure invokes it, not just refine. The promotion
pass sweeps skills for skill-buried-but-universal concerns.

Verified at: `ledger/contracts/procedure.ncl`, `ledger/contracts/core_steps.ncl`,
`ledger/contracts/sub_procedures.ncl`.

---

## P-INTENT — intent-reconstruction

**Purpose.** Weave the literal-mindedness guard at every layer so the machine does
not run the letter and miss the purpose. A procedure that specifies only steps —
without the meta-disposition of intent-reconstruction — runs correctly and arrives
at the wrong destination.

**Honest framing.** This primitive is almost entirely adversarial-review territory.
Its structural residue closes *omission only* — it proves the agent deposited
something, nothing more. Stronger grip is review-only. P-INTENT is the one
genuinely review-dominant primitive — named plainly, not faked. A contract for it
would be the depth-knob dishonesty the system forbids.

**Model.**

- An **always-on disposition** (woven into the invariant-core / ambient layer):
  recover the implicit purpose always; surface it only on ambiguity, drift, or a
  non-goal the literal reading would trample. Not "always ask" — that is the
  over-literal trap reflexively.
- **Checkable residue:**
  - a boundary deposits `purpose` + `non_goals` (presence — closes omission only).
  - goal-overlap cross-check: the deposited `purpose` must share ≥1 salient term
    with the IBC's `goal` field — a weak local consistency check that catches a
    purpose pasted from a different task, still not adequacy.
  - adequacy — was the recovered purpose apt, did it catch real drift → review.
- **Fork-test:** a decision requires explicit alternatives iff the IBC names ≥2
  viable options OR the relevant path selection is genuinely ambiguous. Otherwise
  it is routine — act when ready. The test is structural (counts named options),
  not self-classified.

**Invariants.**

| id | Invariant | Enforcement |
| :--- | :--- | :--- |
| I-I1 | Every boundary deposits non-empty `purpose` + `non_goals` | (S) omission-only presence |
| I-I2 | A procedure entry-state deposits recovered purpose; goal-overlap holds | (S) omission-only + weak consistency check |
| I-I3 | Adequacy — was the recovered purpose apt? | (A) adversarial review — the bulk of this primitive |
| I-I4 | Alternatives required iff the fork-test fires | (S) structural fork-test |

**Contract shape:** mostly conditioning (prevention). The contract floor is a clean
"did the agent deposit purpose + non_goals" check plus the fork-test. Substance is
almost the whole thing; substance is review.

---

## P-TRACK — ambient R/I/U tracking

**Purpose.** Keep the walk coherent about its current task, scope, and constraints
by maintaining a live four-quadrant tracker. This is ambient — active on every task,
with or without a formal campaign. Not maintaining R/I/U is equivalent to declaring
the whole task an unknown-unknown: the worst failure state.

**The four quadrants:**

- **Requirements** — the knowns that bound the goal, pruned to the minimal bounding
  set. Requirement bloat over-constrains and is its own drift surface.
- **Invariants** — the constraints that must hold throughout.
- **Known-unknowns** — each with a `signpost`: the observable that would resolve or
  invalidate it. A filed unknown with a signpost keeps the map honest about where it
  is incomplete.
- **Unknown-unknowns** — surfacing one is high-value signal, not noise. The
  disposition is to file it (promote to known-unknown with a signpost), neither
  suppressing it to reduce friction nor chasing it off the goal.

**The carrier stack.**

| Layer | What it holds | Character |
| :--- | :--- | :--- |
| `AGENTS.md` | Persistent tracker per repo construct — Requirements/Invariants/Unknowns with pointers to full specs | Persistent, authored by `/orient` |
| `context_map.ncl` | Working state, hydrated from the relevant `AGENTS.md` construct | Active per task |
| `.ledger/log/` flight log | Narrative history of decisions and pivots | Linked zettelkasten |

Start a task from the relevant `AGENTS.md` construct, not from scratch. Sync
durable findings back to `AGENTS.md` via the promotion combinator.

**Re-surfacing is non-negotiable.** Recording a tracker once and ignoring it is the
same failure as not having one. The tracker must be re-read and updated at every
step — *reconstruct, don't recall*. The `last_validated` field in
`context_map.ncl` makes staleness checkable:

**Invariants.**

| id | Invariant | Enforcement |
| :--- | :--- | :--- |
| I-T1 | An active task maintains a live R/I/U tracker; absence = failure | (S) presence — ambient, every task |
| I-T2 | Each tracked item carries `grounding` + `last_validated` + `signpost` | (S) structural — `context_map.ncl` enforces this |
| I-T3 | The tracker is re-surfaced and updated at each step/boundary | (S) `last_validated` freshness check; (A) re-surfacing conditioned in invariant-core |
| I-T4 | Are these the right requirements, are the unknowns real? | (A) adversarial review |

**Re-surfacing made un-skippable.** "Maintain + re-surface your R/I/U tracker" is
promoted to a core-step of the P-COMPOSE combinator (universal, like adversarial
review). A walk cannot pass its footprint contract without a fresh tracker deposit.
Machine-gated: did-they-try. Substance: review.

**Reorientation on staleness.** When a landed change contradicts a tracked
Requirement or Invariant — premise-freshness lifted to the persistent tracker —
the tracker must be updated before the next step. This is an ongoing disposition,
not a manual re-run.

Verified at: `ledger/contracts/context_map.ncl`, `ledger/contracts/tracker_freshness.ncl`.

---

## How the five interlock

```
P-GROUND    — the substrate.  What a deposit is, how deposits reference each other.
P-ARSENAL   — capability selection.  Binds `available` to a P-GROUND discovery ref;
              gated by the upstream registry.
P-COMPOSE   — procedure composition.  How procedure states invoke (via P-ARSENAL)
              and compose into per-skill state machines; gated by the sub-procedure
              registry.
P-INTENT    — purpose recovery.  A disposition in the invariant-core (prevention)
              surfacing as omission-only deposits in P-COMPOSE.
P-TRACK     — ambient coherence.  Holds the R/I/U state every task runs against;
              dual of P-INTENT (purpose vs requirements/constraints/unknowns);
              P-ARSENAL selections and P-COMPOSE invocations are judged against it.
```

**Recurring principle.** Every discriminating set — the arsenal registry, the
sub-procedure registry, the required-step set — lives upstream, human-approved, and
un-self-authored. The walk authors only instances and their deposits; it never
authors the sets that judge it.

---

## Key contracts

| Contract | Primitive(s) | Purpose |
| :--- | :--- | :--- |
| `ledger/contracts/deposit.ncl` | P-GROUND | Deposit shape + DepositStore referential integrity |
| `ledger/contracts/arsenal_registry.ncl` | P-ARSENAL | Upstream registry of capability classes and their members |
| `ledger/contracts/sub_procedures.ncl` | P-COMPOSE | Upstream registry of shared sub-procedures |
| `ledger/contracts/procedure.ncl` | P-COMPOSE | The generic procedure combinator |
| `ledger/contracts/core_steps.ncl` | P-COMPOSE | Universal core steps injected into every procedure |
| `ledger/contracts/context_map.ncl` | P-TRACK | Live R/I/U tracker schema |
| `ledger/contracts/tracker_freshness.ncl` | P-TRACK | Freshness gate on the tracker |
