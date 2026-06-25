# Predicate Architecture — The Correction Layer

Predicate's correction machinery is a **multi-layer state machine** whose purpose
is to make procedure drift detectable and mechanically rejectable. It turns the
framework's prose obligations into artifacts that either pass or fail.

This is the natural entry point for predicate's design docs. The companion
documents — [`conditioning-layer.md`](conditioning-layer.md) (the prevention
surface) and [`primitives.md`](primitives.md) (the cross-cutting building blocks)
— both assume the vocabulary defined just below.

---

## Orientation — the vocabulary all three docs use

**Predicate** is an agent-discipline framework. A large language model generating
a long sequence of tokens tends to *drift* — its output wanders away from the goal
as the generation gets longer, because each token is sampled from the accumulating
context and small deviations compound. Predicate exists to fight that drift: it
surrounds an agent's work with explicit boundaries, machine-checkable contracts,
and review gates so that drift is caught and corrected instead of silently shipped.

The terms the three documents lean on:

- **Walk / walker.** A *walk* is one agent generation run — a single uninterrupted
  sequence of model output. The *walker* is the agent performing it. The framework
  treats a walk as a trajectory through possibility-space that can drift, not as a
  reasoning process that "knows" things.
- **IBC (Initial Boundary Condition).** The task prompt-and-contract that sets a
  walk on course: its goal, its non-goals, the files it may touch, and its
  acceptance criteria. The IBC is the boundary a walk is launched from; a saturated
  IBC is what lets an expensive walk run close to one-shot. (A *worker boundary* or
  *node boundary* is an IBC handed to one worker in a larger plan — the same object,
  named by its role.)
- **Deposit.** A structured footprint record a procedure step writes as it runs —
  evidence that a step actually happened, shaped so a reviewer (or a contract) can
  check it. "Coverage is deposited evidence, not a confidence claim" is the
  recurring idea. Deposits are specified in full in [`primitives.md`](primitives.md)
  (P-GROUND).
- **Nickel.** A typed configuration language with a contract system. Predicate
  writes its invariants as Nickel contracts; running `nickel export` over a Nickel
  artifact either succeeds (the data satisfies every contract) or fails. This is
  what makes "the export *is* the gate" literal — there is no separate checker to
  drift from the spec.
- **Harness.** The agent runtime or CLI that runs a walk — for example Claude Code
  or `agy`. Predicate is harness-agnostic: it discovers each harness's capabilities
  at runtime rather than hard-coding them.
- **The Verification Dual.** The framework's core principle: never trust a walk's
  own confidence — close every condition that must hold with the strongest external
  evaluator. Where a deterministic evaluator exists or can be built, use it (the
  *symbolic* path); where none can exist, close the condition with decorrelated
  adversarial review from a context-free agent (the *adversarial* path). All three
  documents borrow this symbolic/adversarial split.

---

## The core design principle

Every requirement, invariant, and constraint in the system names an **enforcement
locus**: either a deterministic Nickel contract or shell gate that fails on
violation (the symbolic path), or a named adversarial-review gate where no
evaluator can exist (the adversarial path). The split is borrowed directly from
the Verification Dual (see the Orientation above):

| Depth | What it closes | Path |
| :--- | :--- | :--- |
| **presence** | omission — did the step run at all? | symbolic (cheap, hard-fail on skip) |
| **structural** | shape — does the deposited evidence conform? | symbolic (engagement-forcing) |
| **quality** | was the work adequate? was the search deep enough? | adversarial review |

A finding is only as strong as its closing path. Presence and structure can be
machine-checked; adequacy cannot — claiming otherwise is the
depth-knob dishonesty the system forbids.

---

## The three-layer topology

The orchestrator is not one state machine; it is a **stack** of them. Higher
layers refine lower ones; the bottom layer holds shared sub-procedures invoked
from inside states at every layer above.

### Layer 0 — Architect control loop (`/campaign`)

```
ABSORB → CLARIFY → SURVEY → PLAN → ORCHESTRATE → DISPATCH ⇄ RECONCILE → CLOSE
```

The expensive planning layer. An architect ingests a human-approved boundary,
saturates context, emits a DAG of worker boundaries, and judges what comes back.
Detail: `skills/campaign/SKILL.md`.

### Layer 1 — Runnable driver (`/orchestration`)

```
DERIVE → RUN_LAYER → DISPATCH → AWAIT → [SURFACE_EXCEED] → RECONCILE
       → MERGE → BOUNDARY → CHECKPOINT → [REALIGN] → CLOSE
```

A refinement of Layer 0's `DISPATCH ⇄ RECONCILE` into a deterministic automaton
a cheaper-tier runner walks: worktree per node, layer schedule, merge at boundary.
Detail: `skills/orchestration/SKILL.md` and
[`docs/orchestration-protocol.md`](orchestration-protocol.md).

The seam between layers: Layer 0 *assumes* a node terminates; Layer 1
*guarantees* converge-or-halt.

### Layer 2 — Shared sub-procedures

Defined once, referenced from inside states at both layers above.

| Sub-procedure | Callers | Authority |
| :--- | :--- | :--- |
| **DISCOVERY** | architect `SURVEY` + every worker `ABSORB` | `ledger/contracts/discovery.ncl` |
| CORE (TDD loop) | feature workers | `skills/core/SKILL.md` |
| REFINE (contraction loop) | polish workers | `skills/refine/SKILL.md` |
| BOUNDARY | pre-dispatch, every tier | `skills/boundary/SKILL.md` |

The composition rule:

```
procedure(skill) = core-steps ∘ skill-specific-required-steps ∘ sub-procedure-refs ∘ output-contract
```

A sub-procedure contract is defined once and referenced by any caller that needs
it — no duplication, no drift between callers. See `ledger/contracts/procedure.ncl`
and `ledger/contracts/core_steps.ncl`.

---

## The state machine as a checked artifact

`skills/orchestration/state_machine.ncl` is the formal model. It is not a diagram;
it is the core orchestrator formalized as **states + transitions + per-transition
guard-contracts**, where each guard is a wired Nickel contract that must pass
before a state can be exited. Running `nickel export` over the state machine
fixture IS the topology gate.

| State | What happens inside | Exit guard |
| :--- | :--- | :--- |
| `ABSORB` | Ingest the boundary; run DISCOVERY | conforms to `campaign_ibc.ncl` |
| `CLARIFY` | Resolve ambiguity or reject the frame | human seam |
| `SURVEY` | Exhaustive review; deposit findings | `findings.ncl` (each finding names its evaluator) |
| `PLAN` | Draw the DAG | `nickel export dag.ncl` passes `Dag ∘ DagNoConflict` + human approval |
| `ORCHESTRATE` | Emit worker boundaries | each IBC conforms to `worker_ibc.ncl`; discipline in enum |
| `DISPATCH ⇄ RECONCILE` | Execute and judge | `reconcile_log.ncl`; verdict gates the merge |
| `CLOSE` | Final sweep + retrospective | `recorder_close_check` exits 0 |
| `HALT` | Reserved-predicate or budget stop | — |

**Amendment loops are first-class.** `RECONCILE → PLAN` and `PLAN → PLAN`
back-edges exist as checked transitions — an amendment is not an escape hatch,
it is a state the machine models explicitly.

**Two design rules:**

1. *Structure at seams, floor at commits.* Nickel guards fire at transitions —
   low-frequency, high-stakes architect boundaries (export the DAG once at
   `PLAN → ORCHESTRATE`). Per-commit gates serve the high-frequency worker-commit
   floor (hygiene always; authority walk-activated). Never drag the expensive
   per-seam check into every commit.

2. *Altitude caveat.* Nickel gates whether you may *leave* a state, not how to
   *perform* its creative interior. A step earns a contract only when it has a
   checkable pre/post-condition. Over-formalizing a state's interior is the
   over-ceremony failure in a Nickel mask — the skill and prose remain the authority
   on how to plan well.

---

## DISCOVERY — the keystone sub-procedure

DISCOVERY is the sub-procedure both the architect (`SURVEY`/`ABSORB`) and every
worker (`ABSORB`) run. Defined once in `ledger/contracts/discovery.ncl` — the
single authority for the step set and deposit schema. Procedure steps reach it via
`invoke.class = "discovery"`, which the sub-procedure registry
(`ledger/contracts/sub_procedures.ncl`) gates: only registered class names are
accepted, so the set that judges a walk is never self-authored. No caller imports
`discovery.ncl` directly; the registry-and-invoke indirection is what prevents
divergence across callers.

### The required step set

| Step | Axis | Modality | What is deposited |
| :--- | :--- | :--- | :--- |
| `establish-universe` | internal / structure | `git ls-files` (+ scoped greps) | the enumerated file universe for the surface — a cited list, never a number |
| `map-intent` | internal / semantics | semantic search (`grepai`) | the intent-relevant loci the universe contains |
| `blast-radius` | internal / coupling | call-graph trace (`grepai trace`) + ref-grep | the change's transitive impact set (loopable; ≥1 footprint satisfies presence) |
| `outward-world` | external / domain | prior-art procedure; web / RFC / literature | ≥2 references for non-trivial algorithms, or an explicit triviality marker |
| `outward-environment` | external / arsenal | survey installed skills / tools / MCP servers | the approach-changing capability found, or "habitual tool sufficient — surveyed" |

The step set is **pinned upstream** — the walk supplies deposits but never authors
the set that judges it. Shrinking the required set fails the contract.

### The search calculus

Search modality is chosen by what is already known about the target:

| You can name… | Modality | Cost | Why |
| :--- | :--- | :--- | :--- |
| an exact token / string | keyword (`rg -F`) | cheapest | often sufficient |
| the shape (a pattern) | regex (ripgrep) | cheap | precise when form is known |
| an approximate form | fuzzy (`fzf`) | cheap | tolerant when confidence is low |
| only the intent (cross-cutting) | semantic (`grepai`) | priciest | finds conceptual matches regex cannot |

Reach for semantic search only when you genuinely cannot name a shape — it is the
fallback for intent, not the default. If a tool is unavailable, degrade to the
next modality that fits what you know and deposit the degraded choice. Never
silently skip the step.

### What the contract bites

- **Presence** — empty `evidence` or `cites` → hard-fail. This alone converts
  "coverage is a confidence claim" into "coverage is deposited evidence."
- **Structure** — `establish-universe` must cite a non-empty enumeration;
  `blast-radius` a set of real paths; `outward-world` either ≥2 references or
  an explicit triviality marker.
- **Quality** — was the search adequate? Routes to adversarial review; never
  asserted as contract-closed.

---

## The gate-locus principle

> Pure logic → Nickel. Effects → a thin shell shim, at the boundary only.

The evaluator hierarchy ranks within the symbolic path: `type/contract > shell
script`. Reaching for shell where a Nickel contract was available under-uses the
hierarchy.

**Architectural validity is proven once** — at the architect boundary (`nickel export
dag.ncl` at `PLAN`), not re-litigated on every worker commit. Per-commit gates stay
minimal and cheap.

**Humans meet only the message gate.** The structural overlay (artifact export, link
integrity, orphan checks) fires on walk-activation (when the `.ledger/active-dag`
pointer is present), never blocking a human commit mid-work. See
`ledger/gate/ledger-validate.sh`.

**One predicate, one language.** Path-containment overlap is defined once, in
Nickel (`ledger/contracts/authorized.ncl`, the same definition `dag.ncl` imports
for its conflict check). The authorization gate `ledger/gate/authorized.py` is a
thin shim around it: it gathers the staged paths (the irreducible git I/O) and
hands them to the Nickel predicate via a single `nickel export`, which returns the
verdict. The only logic the shim keeps is the `fnmatch` glob fallback the
containment predicate deliberately leaves to it. One invariant, one language, no
second copy to drift.

---

## Open-system stance

Predicate is an open system embedded in a diverse tool ecosystem. Four consequences
that bind every layer:

1. **Skills and procedures compose across layers.** Adversarial review is ambient
   — it may invoke discovery, prior-art, or another skill as a sub-step. The
   innermost state machine references sub-procedures by class, never by hard-coding
   one tool.

2. **Arsenal by class, not enumeration.** Name classes of capability — search-tools,
   verification-evaluators, review-skills, discovery, prior-art, formal-modeling —
   and select the context-appropriate member. Enumerate-and-freeze is brittle and
   blind to project-specific tools. See [`docs/primitives.md`](primitives.md) §P-ARSENAL.

3. **Intent-reconstruction at every layer.** A machine executes instructions
   literally; wiring only the steps without the meta-disposition of
   intent-reconstruction misses the purpose. The literal-mindedness guard is woven
   in, not named once.

4. **Unmachine-checkable → independent scrutiny.** Anything that cannot be a
   contract is closed by the adversarial path — decorrelated review from a
   context-free agent — never self-attested.

---

## Key contracts at a glance

| Contract | Purpose | Gate |
| :--- | :--- | :--- |
| `skills/orchestration/state_machine.ncl` | The topology itself — states, transitions, exit-guards | `nickel export` fixture |
| `ledger/contracts/dag.ncl` | DAG validity (`Dag ∘ DagNoConflict`) | `nickel export` at `PLAN` |
| `ledger/contracts/discovery.ncl` | DISCOVERY step set + deposit shapes | shared by campaign + boundary procedures |
| `ledger/contracts/findings.ncl` | SURVEY output — each finding names its evaluator | exit-guard for `SURVEY → PLAN` |
| `ledger/contracts/worker_ibc.ncl` | Worker boundary shape | exit-guard for `ORCHESTRATE` |
| `ledger/contracts/reconcile_log.ncl` | Reconcile round verdicts | exit-guard for `DISPATCH ⇄ RECONCILE` |
| `ledger/contracts/procedure.ncl` | Generic procedure combinator | shared spine for all skill procedures |
| `ledger/gate/ledger-validate.sh` | Per-commit gate dispatcher | pre-commit hook |
| `ledger/gate/coherence_impact.sh` | Orphan + link coherence gate | `RECONCILE` step 3, `LAYER_BOUNDARY` |
