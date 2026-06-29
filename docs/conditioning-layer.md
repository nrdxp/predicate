# Conditioning Layer — System-Prompt Composition

> New to predicate? Read the Orientation in
> [`predicate-architecture.md`](predicate-architecture.md) first — it defines the
> vocabulary (*walk*, *IBC*, *Nickel*, *deposit*, *harness*, the *Verification
> Dual*) this document uses.

The conditioning layer is the **prevention surface** of predicate's
correction/prevention dual. Where the process contracts (`ledger/contracts/`)
enforce procedure *output* after the fact, the conditioning layer enforces
*trajectory* — it biases the walk toward the acceptance region before a miss
occurs, so fewer misses need to be caught.

This document is **normative**: it is the composition contract the
`conditioning/` sources are built against, and it is authored against the live
generator (`conditioning/compose.ncl`) as ground truth. When the generator and
this document disagree, the generator wins and this document is the defect.

---

## Why this surface exists

Predicate's rules can be loaded as **user context** — text the model reads as
advice it can drift from over a long session. Two consequences follow:

1. **Attention dilution.** A reference held at the user level attenuates as
   context grows. The conditioning layer places the core law in the **system
   prompt** — a persistent reference re-attended every step — giving bounded
   tracking error over a long horizon instead of accumulating drift.

2. **Supplement → superset.** Before predicate can *replace* the harness default
   system prompt, it must absorb the behaviors that default prompt provides:
   trust-boundary discipline, dual-use refusal, scope discipline, the commit guard,
   outcome-first communication. The conditioning layer's invariant-core absorbs
   these so no existing behavior is regressed.

**Control-theoretic framing.** The Nickel contracts define the *acceptance region*
in artifact-space — the set of outputs that pass. The conditioning prose is the
*controller* that biases the walk toward that region so it hits first-pass:

- prose = prevention = maximize P(land in acceptance region first-pass)
- contracts = correction = the hard boundary that catches misses cheaply

Neither alone suffices. Prose only *lowers* the miss rate; large or adversarial
context can still dilute it. Contracts remain the hard floor. The Verification
Dual derives from both halves.

**Alignment obligation.** Because prose is a controller targeting the contracts,
the conditioning basin must coincide with the contract's acceptance region. Prose
urging X while a contract checks Y drops hit-ratio and is itself a drift surface.
The conditioning layer and the contract layer are co-designed duals — they cannot
be authored independently.

---

## The layered stack

```
SYSTEM  (law, persistent, GENERATED)
  invariant-core ++ join(modules) ++ role_delta(role)
  → injected at session-open or worker-launch; re-attended every step

PROJECT (hydrated, persistent)
  AGENTS.md — R/I/U tracker per repo construct  (P-TRACK carrier)
  → hydrated from the relevant construct on every walk

TASK    (assignment, ephemeral)
  IBC — the boundary for this dispatch
  → consumed once, discarded when the task completes
```

These three layers have distinct lifetimes and must not bleed into each other.
A per-task requirement is not a project invariant; a project constraint is not
role-specific law. Keeping them separate is the anti-spaghetti guarantee.

The PROJECT layer's R/I/U tracker (Requirements / Invariants / Unknowns) is the
P-TRACK primitive; the SYSTEM layer's harness-surface selection is an instance of
the P-ARSENAL primitive. Both are specified in
[`primitives.md`](primitives.md).

**Composition law:**

```
system_prompt(role) = invariant-core ++ join(modules) ++ role_delta(role)
```

This is the same combinator discipline as the procedure contracts: one combinator,
not N hand-authored prompts. The middle `join(modules)` is the **module segment** —
a per-role list of shared class-station text (see *Modules* below); segments are
joined with `"\n\n"`. In the base case `modules` is empty and the law collapses to
`invariant-core ++ role_delta(role)` — byte-identical to a two-segment form. The
`++` is Nickel string concatenation. `invariant-core` is always the *first*
segment; the injection-rule contracts in `conditioning/compose.ncl` enforce this
structurally.

---

## The invariant-core

`conditioning/core.ncl` — the single source of truth for role-independent law.

**Contents:** Prime Invariants + promoted constitution principles (Truth>Harmony,
Evidence>Authority, Halt>Assumption, Outcomes>Process) + promoted SWE discipline
(commit gate hard-rails, verification protocol, code-edit floor) + always-on
ambient dispositions (intent-reconstruction, Discovery sweep, outward-search
reflex, focus before ceremony, candor, minimal representation) + action caution
(side-effect discipline) + external-source trust boundary + dual-use security
floor + outcome-first communication + harness-capability instructions (live
tracking, structured queries, worker dispatch) + address the human by name.

**Minimality constraint (load-bearing).** The injected core is deliberately
bounded. Injecting the entire ruleset dilutes the persona's focus — the
over-ceremony failure. The selection criterion: **principles always-on;
procedures by-moment.** If a *principle* binds every walker regardless of
discipline, it belongs in core. If it is a *procedure* or applies only to some
roles, it stays a skill or persona overlay — even when that procedure applies to
all roles. Detailed workflow procedures stay routed-by-moment (loaded on demand),
never injected.

This is the principle "when context is scarce, the Prime Invariants are what
survive" made structural rather than aspirational.

---

## Modules — the shared class stations

`conditioning/modules/` contains the **class stations**: text shared by a *class*
of roles, composed *between* core and the role delta. A module is pulled by the
roles that need it and omitted from those that do not — the per-role module list
is the argument that partitions the role space into classes.

| Module | File | Pulled by | Carries |
| :--- | :--- | :--- | :--- |
| **producer** | `modules/producer.ncl` | the four code-writer workers (`core`, `refine`, `form`, `spec`) | the action procedure a writing walk performs — TDD-first, the mandatory trajectory-freeze halts |
| **reviewer** | `modules/reviewer.ncl` | all nine reviewers | the read-only adversarial-reviewer spine — refute-by-default, the seven-field finding contract, correctness/taste classification, the grounded-veto |
| **council** | `modules/council.ncl` | the three council seats | the seat station — the pact (R/I/U as Nickel contracts), the independent-first deliberation protocol, the governance spine (delegation table, checked-hub, barring lifecycle) |

The partition is **mutually exclusive by design**: a reviewer never pulls
`producer` (writing would erase the decorrelation it exists to provide); a seat
never pulls `producer` (seats reason about the architecture, they do not write
code). The `doc-worker` and `boundary-worker` are read-only-ish and pull no module
(their workflow delta is sufficient); the `composer` pulls the rendered
constitution table instead of a class station (see *The constitution render*).

The judge-against **rubric** (strong typing, grounded critique, error handling,
comments, discrepancy resolution) is *not* a module — it lives in `core.ncl` and
reaches every role, because it is a standard every walk is judged against, not a
procedure only writers perform.

---

## Personas — discipline-proportioned overlays

`conditioning/personas/` contains one file per role. Each exports a single
`String` — the discipline-proportioned delta for that role. There are **19 roles
in three classes**:

**Base class** — composer + the six workers (`composer` pulls the constitution
render; the four code-writers pull `producer`; `doc`/`boundary` pull nothing):

| Role | File | Overlay |
| :--- | :--- | :--- |
| `composer` | `personas/composer.ncl` | the live conductor/moderator and front door; scales ceremony, convenes the council, routes the delegation table — not a code-writer |
| `core-worker` | `personas/core-worker.ncl` | `/core` TDD loop (Absorb → Clarify → Plan → Execute) |
| `refine-worker` | `personas/refine-worker.ncl` | `/refine` contraction loop + decorrelated subagent sweeps (MBSS) + hostile-maintainer dialectic |
| `doc-worker` | `personas/doc-worker.ncl` | `/doc` workflow + the plural doc arsenal + Divio-quadrant discipline |
| `form-worker` | `personas/form-worker.ncl` | `/form` formal-modeling workflow + falsification-signpost rule |
| `spec-worker` | `personas/spec-worker.ncl` | `/spec` workflow + BCP-14 normative discipline + forbidden-states-first |
| `boundary-worker` | `personas/boundary-worker.ncl` | `/boundary` S1–S7 sufficiency contraction |

**Reviewer class** — the read-only adversarial fleet; each pulls `reviewer`
(`refuter` is lens-free; the other eight add a lens delta):

| Role | Lens |
| :--- | :--- |
| `refuter-reviewer` | lens-free — attack the artifact as a whole |
| `hickey-reviewer` | structural simplicity (complecting, concept multiplication) |
| `lowy-reviewer` | volatility decomposition (axes of change) |
| `api-reviewer` | API surface coherence + type safety |
| `security-reviewer` | trust-model + taint analysis |
| `git-review-reviewer` | change coherence + commit boundaries |
| `ai-slop-reviewer` | hollow plausibility, hallucinated APIs, transformer cadence |
| `prior-art-reviewer` | measure against production-tested references by citation |
| `vestigial-reviewer` | dead code, orphaned scaffolding, stale breadcrumbs |

**Council class** — the three standing architect-tier seats; each pulls `council`:

| Role | Seat lens |
| :--- | :--- |
| `architect-seat` | the BOUNDARY: goal-fit, strategy, architecture coherence |
| `lead-maintainer-seat` | the MERGE GATE: the hostile elite maintainer who owns the burden |
| `process-auditor-seat` | PROCESS + RESIDUE: audits the composer against pact and law |

A persona overlay is **thin** — exactly one disciplining workflow (or one lens) +
its load-bearing rules (`boundary` skill S7 DISCIPLINE_PROPORTION). It does not
repeat invariant-core or module content; the generator composes those in. A weak
walker under one workflow with the load-bearing rules is a powerhouse; the same
walker under the full ambient mass silently drops invariants.

---

## The constitution render

The composer is the one role conditioned with the project's **council
constitution** — so the live conductor is conditioned with the very law it
conducts. `conditioning/constitution.ncl` is a single Nickel value (seats +
decision-types + a delegation table) conforming to `ledger/contracts/council.ncl`'s
`Constitution`. It is **single-sourced**: two consumers read the same file —

- `conditioning/compose.ncl` **renders** it to prose (a seat list + a
  `decision_type → owner → required_assent` delegation table) and folds it into the
  composer's prompt as the module segment. The rows are *generated* from the value,
  never hand-copied: editing the constitution re-renders the prompt.
- `ledger/contracts/council_apply.ncl` **imports** it as the constitution threaded
  into `DecisionLedger`, so the production merge-consent gate
  (`ledger/gate/council_consent.sh`) validates real decision-ledgers against
  predicate's own law.

One source, two consumers, no copy to drift. (The fixture
`ledger/fixtures/council/constitution.yaml` mirrors it in spirit for the law's
self-contained unit tests; neither derives from the other.)

---

## The generator — `conditioning/compose.ncl`

`compose.ncl` is the functional core. Pure Nickel — no bash, no side effects. Its
job: compose `core ++ join(modules) ++ role_delta` for each role and enforce the
injection-rule contracts on every output. It evaluates to a **record keyed by role
identifier**; each value is a `String` guarded by `HasCore` (and, for module-bearing
roles, `HasModule` / `HasLens`).

The three-segment combinator:

```nickel
let compose : Array String -> String -> String = fun role_modules role_delta =>
  std.string.join "\n\n" ([core_text] @ role_modules @ [role_delta])
in
```

Per-role wiring (abridged — see the source for all 19 fields):

```nickel
{
  composer         | HasCore = compose [council_render] personas.composer,
  "core-worker"    | HasCore = compose [producer] personas."core-worker",
  "doc-worker"     | HasCore = compose [] personas."doc-worker",

  # reviewers: core ++ reviewer_module ++ lens-delta
  "refuter-reviewer"  | HasCore | HasModule reviewer_module
    = compose [reviewer_module] reviewers."refuter-reviewer",
  "hickey-reviewer"   | HasCore | HasModule reviewer_module | HasLens reviewers."hickey-reviewer"
    = compose [reviewer_module] reviewers."hickey-reviewer",

  # seats: core ++ council_module ++ seat-delta
  "architect-seat"    | HasCore | HasModule council_module
    = compose [council_module] council."architect-seat",
}
```

Callers access a role's prompt via the role field:

```bash
echo '(import "compose.ncl").composer' \
  | nickel export --format text -I conditioning/
```

**Callers must not:**
- bypass the role-field interface (concatenate core, modules, or persona
  themselves outside `compose.ncl`);
- cache the output string across `core.ncl`, module, or persona edits — generate
  on every launch (`nickel export` is cheap).

---

## The injection-rule contracts

Three sibling contracts, all the same verbatim-substring rule, parameterized by the
text they guard:

```nickel
let HasCore   : Dyn            = std.contract.from_predicate (fun s => std.string.contains core_text (s | String)) in
let HasModule : String -> Dyn  = fun m => std.contract.from_predicate (fun s => std.string.contains m (s | String)) in
let HasLens   : String -> Dyn  = fun l => std.contract.from_predicate (fun s => std.string.contains l (s | String)) in
```

- **`HasCore`** guards *every* role field — `core_text` (the actual string imported
  from `core.ncl`, not a hash) must appear as a contiguous substring. Core appears
  first by construction.
- **`HasModule m`** guards every module-bearing role — the nine reviewers carry
  `HasModule reviewer_module`, the three seats carry `HasModule council_module`.
- **`HasLens l`** guards the eight *lensed* reviewers — each must contain its own
  lens delta. The lens-free `refuter` carries no `HasLens`.

**Failure is fatal.** When `nickel export` evaluates a field whose composed string
violates a guard, the export fails with a contract violation (exit non-zero) and no
prompt is emitted; `install.sh` treats a non-zero exit as fatal and writes no
harness surface. The negative controls `conditioning/probe_no_core.ncl` and
`conditioning/probe_no_module.ncl` prove the `HasCore` / `HasModule` contracts bite
(both carry `# EXPECT: fail`).

**What the contracts do not check** (covered by adversarial review): whether
`core.ncl` holds the right law (content adequacy); whether a persona is
discipline-proportioned; whether `core_text` changed since last install (the install
regenerates on every persistent install to close this gap).

---

## Delivery — `conditioning/install.sh`

`install.sh` is the only bash in the conditioning layer — the effect boundary
(functional-core / imperative-shell). It materializes the generated prompts into
each harness's **native system-prompt surface** at install time — no runtime
probing, no per-launch flag injection. Adding a new harness = one install branch;
`compose.ncl` is unchanged.

**Claude Code** — two surface kinds:

- **Output style** → `~/.claude/output-styles/predicate-composer.md`
  (display name `Predicate Composer`). Frontmatter `keep-coding-instructions:
  false` empties Claude Code's built-in software-engineering block while preserving
  tool definitions, environment info, agent identity, and safety scaffolding. The
  composer prompt becomes the behavioral half with nothing contradicting beneath.
  The composer is delivered *only* as the output style — it is not a dispatchable
  agent.
- **Worker agents** → `~/.claude/agents/predicate-<role>.md`, one file per
  dispatchable role: the **18** agent roles (6 workers + 9 reviewers + 3 seats).
  The agent body becomes that subagent's full system prompt — a convenience cache;
  the composer may also inject a freshly generated persona dynamically via the
  native subagent path.

**agy** — one managed block:

- **GEMINI.md** → `~/.gemini/GEMINI.md`. The composer prompt is appended inside a
  managed block (between `# >>> predicate conditioning block >>>` sentinels); user
  content outside the block is preserved on re-install.

Selecting the output style is a separate step (`/output-style` or
`"outputStyle": "Predicate Composer"` in `settings.json`) and belongs to bootstrap,
not this generator. The install regenerates every prompt from source on each run —
no stale committed copy.

---

## Design decisions

| Decision | Rationale |
| :--- | :--- |
| ONE `core.ncl`, never copied | Generate-don't-copy; verbatim injection contract closes drift |
| Thin persona overlays (not full prompts) | Over-ceremony dilutes persona focus; core + modules injected by generator |
| Class stations as modules, pulled per role | The producer/reviewer/council partition is the role-space decomposition; a reviewer that pulled producer would lose its decorrelation |
| Constitution single-sourced (Nickel value), rendered into the composer | The live conductor is conditioned with the very law the merge-consent gate enforces; rows generated, never hand-copied |
| Nickel is the generator, bash only at effect boundary | Functional-core / imperative-shell; composition stays pure and testable |
| Native delivery surfaces, not a runtime-probed adapter ladder | Each harness gets one install branch; `compose.ncl` is unchanged and harness-agnostic |
| `std.string.contains` for the injection contracts | Verbatim substring check; export fails on violation |
| `++` for string concatenation | Native Nickel operator (arrays use `@`, strings use `++`) |
| Per-role record fields in `compose.ncl` | `nickel export --format text` emits a String; a keyed record lets callers access fields cleanly |
| Generate on every launch, no caching | Always current; `nickel export` is cheap |

---

## Key files

| Path | Role |
| :--- | :--- |
| `conditioning/core.ncl` | The ONE invariant-core source |
| `conditioning/modules/*.ncl` | The three class stations (producer, reviewer, council) |
| `conditioning/personas/*.ncl` | Thin role deltas — 19, one per role |
| `conditioning/constitution.ncl` | The single-sourced council constitution (rendered + gate-imported) |
| `conditioning/compose.ncl` | Generator + injection-rule contracts (`HasCore` / `HasModule` / `HasLens`) |
| `conditioning/install.sh` | Effect boundary — delivers to native harness surfaces |
| `conditioning/probe_no_core.ncl`, `probe_no_module.ncl` | Negative controls proving the contracts bite |
| `conditioning/test_conditioning.sh` | Hermetic e2e: per-role surfaces, module partition, constitution render |
