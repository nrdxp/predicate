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

---

## Why this surface exists

Predicate's rules are currently loaded as **user context** — text the model reads
as advice it can drift from over a long session.
Two consequences follow:

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
Dual derived from both halves.

**Alignment obligation.** Because prose is a controller targeting the contracts,
the conditioning basin must coincide with the contract's acceptance region. Prose
urging X while a contract checks Y drops hit-ratio and is itself a drift surface.
The conditioning layer and the contract layer are co-designed duals — they cannot
be authored independently.

---

## The layered stack

```
SYSTEM  (law, persistent, GENERATED)
  invariant-core ++ persona(role)
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
system_prompt(role) = invariant-core ++ persona(role)
```

This is the same combinator discipline as the procedure contracts: one combinator,
not N hand-authored prompts. The `++` is Nickel string concatenation. The
invariant-core is injected *verbatim* — the injection-rule contract in
`conditioning/compose.ncl` enforces this structurally.

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

**Minimality constraint (load-bearing), recalibrated.** The injected core is
deliberately bounded. Injecting the entire ruleset dilutes the persona's focus —
the over-ceremony failure. The selection criterion: **principles always-on;
procedures by-moment.** If a *principle* binds every walker regardless of
discipline, it belongs in core. If it is a *procedure* or applies only to some
roles, it stays a skill or persona overlay — even when that procedure applies to
all roles. Detailed workflow procedures stay routed-by-moment (loaded on demand),
never injected.

This is the principle "when context is scarce, the Prime Invariants are what
survive" made structural rather than aspirational.

---

## Personas — discipline-proportioned overlays

`conditioning/personas/` contains one file per role. Each exports a single
`String` — the discipline-proportioned delta for that role.

| Role | File | Overlay |
| :--- | :--- | :--- |
| `composer` | `personas/composer.ncl` | `/campaign` + `/orchestration` loops; moderator/conductor of the worker fleet, not a code-writer |
| `core-worker` | `personas/core-worker.ncl` | `/core` loop + load-bearing engineering/testing rules |
| `refine-worker` | `personas/refine-worker.ncl` | `/refine` loop + multi-boundary subagent sweeps (decorrelated review panels) + hostile-maintainer rules |
| `doc-worker` | `personas/doc-worker.ncl` | documentation workflow + its load-bearing rules |
| `form-worker` | `personas/form-worker.ncl` | formal-modeling workflow |
| `spec-worker` | `personas/spec-worker.ncl` | specification workflow |
| `boundary-worker` | `personas/boundary-worker.ncl` | boundary-drafting workflow |

A persona overlay is **thin** — exactly one disciplining workflow + its
load-bearing rules (`boundary` skill S7 DISCIPLINE_PROPORTION). It does not
repeat invariant-core content; the generator composes core in. A weak walker
under one workflow with the load-bearing rules is a powerhouse; the same walker
under the full ambient mass silently drops invariants.

---

## The generator — `conditioning/compose.ncl`

`compose.ncl` is the functional core. Pure Nickel — no bash, no side effects. Its
job: compose `core ++ persona(role)` and enforce the injection-rule contract on
every output.

```nickel
let core_text : String = import "core.ncl" in

let personas = {
  composer        = import "personas/composer.ncl",
  "core-worker"   = import "personas/core-worker.ncl",
  "refine-worker" = import "personas/refine-worker.ncl",
  "doc-worker"    = import "personas/doc-worker.ncl",
  "form-worker"   = import "personas/form-worker.ncl",
  "spec-worker"   = import "personas/spec-worker.ncl",
  "boundary-worker" = import "personas/boundary-worker.ncl",
} in

let HasCore = std.contract.from_predicate
  (fun s => std.string.contains core_text s)
in

{
  composer        | HasCore = core_text ++ "\n\n" ++ personas.composer,
  "core-worker"   | HasCore = core_text ++ "\n\n" ++ personas."core-worker",
  # … one field per role …
}
```

`compose.ncl` evaluates to a **record keyed by role identifier**. Each value is a
`String` guarded by `HasCore`. Callers access a role's prompt via the `--field`
flag (which selects a single field of the record output):

```bash
nickel export --format text \
  -I conditioning/ \
  --field composer \
  conditioning/compose.ncl
```

**Callers must not:**
- bypass the role-field interface (e.g. concatenate core and persona themselves
  outside `compose.ncl`);
- cache the output string across `core.ncl` or persona edits — generate on every
  launch (`nickel export` is cheap).

---

## The injection-rule contract

`HasCore` as defined above:

```nickel
let HasCore = std.contract.from_predicate
  (fun s => std.string.contains core_text s)
```

- `core_text` is the value imported from `core.ncl` — the actual string, not a
  hash or summary.
- When `nickel export` evaluates a field annotated `| HasCore` and the string does
  not contain `core_text`, the export fails with a contract violation (exit
  non-zero). No prompt is emitted.
- **Failure is fatal:** `install.sh` must treat a non-zero `nickel export` exit
  as a fatal error — no harness surface is written.

**What the contract checks:** presence of `core_text` as a contiguous substring.
Core appears first by construction (`core_text ++ "\n\n" ++ persona_overlay`).

**What the contract does not check** (covered by adversarial review):
- whether `core.ncl` itself contains the right law (content adequacy);
- whether the persona overlay is discipline-proportioned;
- whether `core_text` has changed since last install (the install step regenerates
  on every persistent install to close this gap).

---

## Delivery — `conditioning/install.sh`

`install.sh` is the only bash in the conditioning layer — the effect boundary
(functional-core / imperative-shell). It discovers the best available conditioning
surface at runtime and writes the generated prompt there.

### Native delivery surfaces

`install.sh` materializes the generated prompts into each harness's **native
system-prompt surface** at install time — no runtime probing, no per-launch
flag injection. Adding a new harness = one install branch in `install.sh`;
`compose.ncl` is unchanged.

**Claude Code** — two surfaces are written:

- **Output style** → `~/.claude/output-styles/predicate-composer.md`
  Frontmatter `keep-coding-instructions: false` empties Claude Code's built-in
  software-engineering block while preserving tool definitions, environment info,
  agent identity, and safety scaffolding. The markdown body is appended to the
  system prompt, so predicate's law becomes the behavioral half with nothing
  contradicting underneath.
- **Worker agents** → `~/.claude/agents/predicate-<role>.md` (one file per
  worker role: `core-worker`, `refine-worker`, `doc-worker`, `form-worker`,
  `spec-worker`, `boundary-worker`). The agent body becomes that subagent's full
  system prompt — a convenience cache; the composer may also inject a freshly
  generated persona dynamically via the native subagent path.

**agy** — one managed block is written:

- **GEMINI.md** → `~/.gemini/GEMINI.md`
  A managed block (between `# >>> predicate conditioning block >>>` sentinels)
  is appended into the system prompt. User content outside the block is
  preserved on re-install.

The install regenerates prompts from source on every run (no stale committed
copy). The role chosen per surface is fixed at install time for persistent
surfaces; the orchestrator generates fresh per-role prompts at dispatch time
using the same `compose.ncl` call.

---

## Design decisions

| Decision | Rationale |
| :--- | :--- |
| ONE `core.ncl`, never copied | Generate-don't-copy; verbatim injection contract closes drift |
| Thin persona overlays (not full prompts) | Over-ceremony dilutes persona focus; core injected by generator |
| Nickel is the generator, bash only at effect boundary | Functional-core / imperative-shell; composition stays pure and testable |
| Native delivery surfaces, not a runtime-probed adapter ladder | Each harness gets one install branch; `compose.ncl` is unchanged and harness-agnostic |
| `std.string.contains` for injection-rule contract | Verbatim substring check; export fails on violation |
| `++` for string concatenation | Native Nickel operator (arrays use `@`, strings use `++`) |
| Per-role record fields in `compose.ncl` | `nickel export --format text` emits a String; a keyed record lets callers access fields cleanly |
| Generate on every launch, no caching | Always current; `nickel export` is cheap |

---

## Key files

| Path | Role |
| :--- | :--- |
| `conditioning/ARCHITECTURE.md` | Normative composition contract — slot structure and interfaces |
| `conditioning/core.ncl` | The ONE invariant-core source |
| `conditioning/personas/*.ncl` | Thin role deltas (one per role) |
| `conditioning/compose.ncl` | Generator + injection-rule contract |
| `conditioning/install.sh` | Effect boundary — delivers to native harness surfaces |
