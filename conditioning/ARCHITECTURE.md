# Conditioning Architecture — System-Prompt Composition Model

> **Status: NORMATIVE (campaign artifact).** This document is the composition
> contract downstream nodes build against. The slot structure and interfaces
> defined here are fixed before `invariant-core`, `personas`, and `injection`
> author their content — preventing copy-paste spaghetti by construction.
>
> Sources: `conditioning-layer.md` (§composition stack, §dynamic harness
> wiring, §injection mechanism); `primitives-spec.md` (§P-COMPOSE, §P-ARSENAL).

---

## 1. The Layered Stack

Three layers, three scopes, three lifetimes:

```
SYSTEM  (law, persistent, GENERATED)
  invariant-core ++ persona(role)
  → injected at session-open or worker-launch; re-attended every step

PROJECT (hydrated, persistent)
  AGENTS.md  —  R/I/U tracker per repo construct  (P-TRACK carrier)
  → hydrated from the relevant construct on every walk

TASK    (assignment, ephemeral)
  node IBC  —  the worker boundary for this dispatch
  → consumed once, discarded when the node completes
```

**Why this split is load-bearing.**

- The SYSTEM layer is the *controller* (conditioning-layer.md §formal role): it
  biases the autoregressive walk toward the acceptance region defined by the
  Nickel contracts. Prose here lowers the miss rate; it does not eliminate it —
  the contracts remain the hard floor.
- The PROJECT layer is the *coherence substrate* (P-TRACK): Requirements,
  Invariants, Known-unknowns, with `grounding`/`last_validated`/`signpost`
  per item. Kept separate from SYSTEM because it changes per repo construct
  while SYSTEM changes only per role.
- The TASK layer is ephemeral intent. It must not bleed into the persistent
  layers — a per-task requirement is not a project invariant.

**Composition law.**

```
system_prompt(role) = invariant-core ++ persona(role)
```

This is P-COMPOSE applied to the system prompt: a single combinator, not N
hand-authored prompts. The `++` is Nickel string concatenation (verified:
`"a" ++ "b"` → `"ab"`). The combinator is the anti-spaghetti guarantee;
`invariant-core` is injected *verbatim* — the injection-rule contract enforces
this structurally (§4).

---

## 2. On-Disk Slot Structure

```
conditioning/
  ARCHITECTURE.md      ← THIS FILE (authored by: conditioning-architecture node)
  core.ncl             ← the ONE invariant-core source  (authored by: invariant-core node)
  personas/
    architect.ncl      ← thin role delta  (authored by: personas node)
    core-worker.ncl    ←   "              (authored by: personas node)
    refine-worker.ncl  ←   "              (authored by: personas node)
    doc-worker.ncl     ←   "              (authored by: personas node)
    form-worker.ncl    ←   "              (authored by: personas node)
    spec-worker.ncl    ←   "              (authored by: personas node)
    boundary-worker.ncl ←  "             (authored by: personas node)
  compose.ncl          ← generator + injection-rule contract  (authored by: injection node)
  install.sh           ← ONLY bash; effect boundary / injection ladder  (authored by: injection node)
```

### Slot contracts for downstream nodes

**`core.ncl`** (authored by: `invariant-core` node)

- Must export a single `String` value — the complete behavioral-law prose. This
  is the **full replacement** for the harness default behavioral block (Claude
  Code output style, `keep-coding-instructions: false`), not an append.
- Contents: the Prime Invariants (rules.md §2) + the promoted constitution
  principles (Truth>Harmony, Evidence>Authority, Halt>Assumption,
  Outcomes>Process) + the promoted SWE discipline (engineering code-edit floor +
  verification protocol + commit gate) + the always-on ambient dispositions
  (intent-reconstruction, the Discovery sweep, verify-everything / trust-boundary,
  outward-search, focus-selector, candor) + the derived comms/action principles
  (minimal representation, action caution, outcome-first) + the ported default
  floor (scope discipline, dual-use refusal, commit-only-when-authorized,
  absorbed CLAUDE.md overrides) + the harness-capability instructions (live
  tracking, structured queries).
- MINIMALITY CONSTRAINT, recalibrated: **principles always-on; procedures
  by-moment.** The old rule ("core = law only, SWE stays a routed skill") is
  WRONG now that the harness's own SWE block is disabled — leaving SWE
  routed-by-moment would open a coverage gap the default no longer fills. So the
  *principles* of constitution and engineering promote into core; their *detailed
  procedures* (the by-moment reference halves of those skills, plus every
  workflow skill) stay routed-by-moment, not injected. Rationale: injecting full
  procedural mass silences the persona's focus (conditioning-layer.md §minimality
  constraint), but omitting a binding principle leaves drift uncorrected. Rule:
  if a *principle* binds EVERY walker regardless of discipline, it belongs in
  core; if it is a *procedure* or applies only to some roles, it stays a skill or
  a persona overlay.
- Export form: `nickel export --format text conditioning/core.ncl` → a plain
  string, ready to concatenate.

**`personas/*.ncl`** (authored by: `personas` node)

- Each file exports a single `String` value — the discipline-proportioned delta
  for that role.
- THIN overlay only: exactly one disciplining workflow + its load-bearing rules
  (boundary skill S7 DISCIPLINE_PROPORTION, conditioning-layer.md §2). Not a
  full standalone prompt — the generator composes in core.
- The persona overlay must NOT repeat invariant-core content. Rationale:
  duplication is drift surface; the injection-rule contract in `compose.ncl`
  guarantees the core appears in the final output.
- Export form: `nickel export --format text conditioning/personas/<role>.ncl` →
  plain string, the delta.
- Role-to-file mapping (exact filenames, no variation):

  | Role identifier  | File                        |
  | :---             | :---                        |
  | `architect`      | `personas/architect.ncl`    |
  | `core-worker`    | `personas/core-worker.ncl`  |
  | `refine-worker`  | `personas/refine-worker.ncl`|
  | `doc-worker`     | `personas/doc-worker.ncl`   |
  | `form-worker`    | `personas/form-worker.ncl`  |
  | `spec-worker`    | `personas/spec-worker.ncl`  |
  | `boundary-worker`| `personas/boundary-worker.ncl`|

**`compose.ncl`** (authored by: `injection` node) — see §3 for interface spec.

**`install.sh`** (authored by: `injection` node) — see §5 for behaviour spec.

---

## 3. The `compose.ncl` Generator Interface

`compose.ncl` is the functional core of the conditioning layer. It is pure
Nickel — no bash, no side effects. Its sole job: compose `core ++ persona(role)`
and enforce the injection-rule contract on every output.

### Verified Nickel idioms (tested against Nickel 1.17.0)

- **String concatenation:** `++` operator. `"a" ++ "\n\n" ++ "b"` → `"a\n\nb"`.
- **Imports:** `let core_text = import "core.ncl" in ...` (path relative to the
  importing file; `NICKEL_IMPORT_PATH` or `-I` for search dirs).
- **Record field access:** `personas_record.architect` or
  `std.record.get "core-worker" personas_record` (for hyphenated keys).
- **Contract definition:**
  `std.contract.from_predicate (fun s => <Bool expression>)`.
- **Substring check:** `std.string.contains needle haystack : String -> String -> Bool`.
  Argument order: needle first, haystack second (verified).
- **Type annotation:** `field_name : Type = expr` inside a record.
- **Text export:** `nickel export --format text <file>` emits the top-level
  string value. For a record, access a specific field via a wrapper file or
  the customize-mode `-- --override` flag.

### Shape of `compose.ncl`

```nickel
# compose.ncl
#
# Generator: system_prompt(role) = core ++ persona(role)
# Contract:  every generated string contains the invariant-core verbatim.
#
# EXPORT INTERFACE
# ----------------
# compose.ncl evaluates to a record keyed by role identifier.
# Each field value is a String guarded by the HasCore contract.
# Callers (install.sh, orchestrator) access a role's prompt via:
#   nickel export --format text compose.ncl -- <role>=<value>
# or via wrapper:
#   (import "compose.ncl").<role>
#
# AUTHORING NOTE (for the injection node)
# ----------------------------------------
# 1. Import core.ncl and all persona/*.ncl files at the top.
# 2. Define HasCore using std.contract.from_predicate + std.string.contains.
# 3. Build the output record: one field per role, each composed and contracted.
# 4. Do NOT add any field that omits core_text — the contract fails on export.

let core_text : String = import "core.ncl" in

let personas : { _ : String } = {
  architect     = import "personas/architect.ncl",
  "core-worker" = import "personas/core-worker.ncl",
  "refine-worker" = import "personas/refine-worker.ncl",
  "doc-worker"  = import "personas/doc-worker.ncl",
  "form-worker" = import "personas/form-worker.ncl",
  "spec-worker" = import "personas/spec-worker.ncl",
  "boundary-worker" = import "personas/boundary-worker.ncl",
} in

# INJECTION-RULE CONTRACT — see §4 for rationale and failure semantics.
# Verified: std.string.contains "needle" "haystack" : Bool
let HasCore : Dyn = std.contract.from_predicate
  (fun s => std.string.contains core_text s)
in

# system_prompt(role) = core_text ++ "\n\n" ++ persona(role)
# All role fields are typed HasCore; export fails if core_text is absent.
{
  architect       | HasCore = core_text ++ "\n\n" ++ personas.architect,
  "core-worker"   | HasCore = core_text ++ "\n\n" ++ personas."core-worker",
  "refine-worker" | HasCore = core_text ++ "\n\n" ++ personas."refine-worker",
  "doc-worker"    | HasCore = core_text ++ "\n\n" ++ personas."doc-worker",
  "form-worker"   | HasCore = core_text ++ "\n\n" ++ personas."form-worker",
  "spec-worker"   | HasCore = core_text ++ "\n\n" ++ personas."spec-worker",
  "boundary-worker" | HasCore = core_text ++ "\n\n" ++ personas."boundary-worker",
}
```

**Calling convention for callers of `compose.ncl`:**

```bash
# Extract one role's prompt as plain text — the canonical call from install.sh
# and from the orchestrator's per-launch injection:
nickel export --format text \
  -I conditioning/ \
  conditioning/compose.ncl \
  -- --override 'role="architect"'
# → plain string, ready to pass to the harness

# Or via a one-line wrapper (no customize mode needed):
echo '(import "compose.ncl").architect' \
  | nickel export --format text -I conditioning/
```

**What `compose.ncl` exports (normative):**

- A Nickel **record** keyed by role identifier.
- Each value is a `String` guarded by `HasCore`.
- Callers must NOT bypass the role-field interface (e.g. by concatenating
  core and persona themselves outside `compose.ncl`).
- Callers must NOT cache the output string across `core.ncl` or persona
  edits — generate on every launch (`nickel export` is cheap).

---

## 4. The Injection-Rule Contract Spec

**Purpose.** The invariant-core must appear *verbatim* in every generated
system prompt. This is the anti-drift structural guarantee: no persona or
harness adapter can accidentally drop the core.

**Contract identity.** `HasCore` as defined in §3:

```nickel
let HasCore = std.contract.from_predicate
  (fun s => std.string.contains core_text s)
```

- `core_text` is the value imported from `core.ncl` — not a hash, not a
  summary, the actual string.
- `std.string.contains needle haystack` (Nickel 1.17.0): returns `true` iff
  `needle` is a substring of `haystack`.
- When `nickel export` evaluates a field annotated `| HasCore` and the string
  does NOT contain `core_text`, the export fails with a contract violation
  (verified: `"contract broken by a value"`, exit non-zero). No prompt is
  emitted.

**Failure semantics (verified):**
- Success: the full composed string is emitted on stdout, exit 0.
- Failure: `nickel export` prints `error: contract broken by a value` with the
  violating location, exits non-zero. `install.sh` must treat non-zero exit as
  a fatal error (abort, do not write any harness surface).

**What the contract checks (normative):**
- Presence: `core_text` appears as a contiguous substring of the generated
  prompt string.
- The contract does NOT check: ordering of core vs persona (core appears first
  by construction — `core_text ++ "\n\n" ++ persona_overlay`); formatting
  beyond verbatim presence; content adequacy of the core or persona.

**What the contract does NOT check (must be covered by adversarial review):**
- Whether `core.ncl` itself contains the right law (content adequacy).
- Whether the persona overlay is discipline-proportioned (S7 compliance).
- Whether `core_text` has changed since last install (staleness — `install.sh`
  regenerates on every persistent install to close this gap).

---

## 5. Harness-Agnostic Delivery

### The Arsenal-Class Ladder (P-ARSENAL instance)

Injection is an instance of P-ARSENAL's `conditioning-surface` class (bias:
`strongest`). The ladder is a graceful degradation sequence; `install.sh`
discovers the best available surface at runtime — it does NOT pre-encode
per-harness mechanisms.

```
Tier 1 — system prompt (strongest)
  Claude Code:  --append-system-prompt "<prompt>"  (per-launch)
                output-style persistent install     (session-level)
  API callers:  system parameter
  agy:          --system-prompt "<prompt>"          (per-launch)

Tier 2 — globally-read rules file (just under system prompt)
  Claude Code:  CLAUDE.md managed block (@-import)  ← current predicate fallback
  Cursor:       .cursorrules
  Generic:      AGENTS.md prepend section

Tier 3 — initial-prompt prepend (last resort)
  agy:          --prompt-interactive "SYSTEM:\n<prompt>\n\nTASK:\n<IBC>"
  Any harness:  prepend the generated prompt to the first user turn
```

Predicate's current `CLAUDE.md @import` is the Tier 2 fallback — the campaign
adds Tier 1 above it where available. Tier 2 remains the graceful floor.

Discovery at runtime: `install.sh` probes the environment for harness
capabilities (e.g. `claude --help | grep append-system-prompt`) and selects
the highest available tier. Adding a harness = one thin detection + install
branch in `install.sh`; `compose.ncl` is unchanged.

### Two Injection Modes

Both modes share the same `compose.ncl` output and the same ladder.

**Mode A — Persistent Install (session-level)**

Use for: the human's own sessions; the architect character.

```bash
# install.sh persistent install (pseudocode — injection node authors the real impl)
PROMPT=$(nickel export --format text -I conditioning/ conditioning/compose.ncl \
           -- --override "role=\"$ROLE\"")

# Tier 1 available (Claude Code output-style / CLAUDE.md managed block)?
#   → write prompt to the harness's persistent system surface
# Tier 2 only?
#   → write to CLAUDE.md managed block
```

The install regenerates the prompt from source on every run, so the installed
copy is always current with `core.ncl` and persona edits.

**Mode B — Per-Launch Injection (worker dispatch)**

Use for: orchestrator dispatching a worker node at a specific discipline tier.

```bash
# Orchestrator dispatch pattern (pseudocode)
PROMPT=$(nickel export --format text -I conditioning/ conditioning/compose.ncl \
           -- --override "role=\"refine-worker\"")

# Claude Code (Tier 1 available):
claude --append-system-prompt "$PROMPT" --model <tier> \
  --prompt-interactive "$(cat node_ibc.md)"

# agy (Tier 1 available):
agy --system-prompt "$PROMPT" --model <tier> \
  --prompt-interactive "$(cat node_ibc.md)"

# Tier 1 unavailable (agy without --system-prompt support):
agy --model <tier> \
  --prompt-interactive "SYSTEM CONDITIONING:\n$PROMPT\n\n---\nTASK:\n$(cat node_ibc.md)"
```

Generation is on-launch (`nickel export` is cheap — no stale installed copy
in the per-launch mode). The role is chosen at dispatch time by the
orchestrator; the surface is discovered at dispatch time by `install.sh`.

---

## 6. Design Decisions (Rationale Trace)

| Decision | Source | Rationale |
| :--- | :--- | :--- |
| ONE `core.ncl`, never copied | conditioning-layer.md §composition stack | Generate-don't-copy; verbatim contract closes drift |
| Thin persona overlays (not full prompts) | conditioning-layer.md §2, S7 | Over-ceremony dilutes persona focus; core injected by generator |
| Nickel is the generator, bash only at effect boundary | conditioning-layer.md §on disk, IBC K10 | Functional-core / imperative-shell; composition stays pure |
| Injection as P-ARSENAL ladder, not per-harness adapter | conditioning-layer.md §injection mechanism, primitives-spec.md §P-ARSENAL | Harness-agnostic; new harness = one detection branch |
| `std.string.contains` for injection-rule contract | Nickel 1.17.0 stdlib (verified) | Verbatim substring check; export fails on violation |
| `++` for string concatenation | Nickel 1.17.0 syntax (verified) | Native operator; arrays use `@` but strings use `++` |
| Per-role record fields in `compose.ncl`, not a parameterized function | Nickel export model | `nickel export --format text` emits a String; a record keyed by role lets callers access fields via wrapper or customize mode |
| Generate on every launch, no caching | conditioning-layer.md §dynamic harness wiring | Always current; `nickel export` is cheap |

---

## 7. Reserved Halts (Inherited from IBC)

**HALT condition:** if harness-agnostic injection cannot be expressed as the
arsenal-class ladder above (a harness requires pre-encoding its mechanism into
`compose.ncl` or a separate adapter file) → report to architect. This would
break the harness-agnostic premise.

**Current status:** the ladder as specified handles Claude Code, agy, and the
generic API case. No halt triggered. U-HARNESS is dissolved (conditioning-
layer.md §known-unknowns): injection is discovery-at-runtime, not pre-encoding.

---

## 8. Downstream Node Checklist

Each downstream node can verify it is building against the right slot:

**`invariant-core` node** — writes `conditioning/core.ncl`:
- [ ] Top-level value is a `String` (not a record).
- [ ] `nickel export --format text conditioning/core.ncl` exits 0 and emits
      non-empty prose.
- [ ] Contents: Prime Invariants + promoted constitution & SWE *principles* +
      always-on ambient dispositions (incl. the Discovery sweep) + derived
      comms/action principles + ported floor + harness-capability instructions.
- [ ] Carries promoted *principles* but NOT *procedures*: no role-specific
      persona content, no by-moment workflow procedure (those stay skills).

**`personas` node** — writes `conditioning/personas/<role>.ncl` for each role:
- [ ] Each file's top-level value is a `String`.
- [ ] `nickel export --format text conditioning/personas/<role>.ncl` exits 0.
- [ ] Content is the discipline delta only — does NOT repeat `core.ncl` content.
- [ ] Filenames match the role table in §2 exactly.

**`injection` node** — writes `conditioning/compose.ncl` and `conditioning/install.sh`:
- [ ] `compose.ncl` imports `core.ncl` and all `personas/*.ncl` files.
- [ ] `HasCore` contract is defined exactly as in §3 using
      `std.contract.from_predicate` + `std.string.contains core_text`.
- [ ] Each role field is annotated `| HasCore`.
- [ ] `nickel export --format text conditioning/compose.ncl -- --override 'architect="..."'`
      (or wrapper) emits the composed string for a valid role.
- [ ] Injecting a persona-only string (no core) fails the export with a contract
      violation (verify by running the bad case manually).
- [ ] `install.sh` treats non-zero `nickel export` exit as fatal (no harness
      surface written).
- [ ] `install.sh` probes for Tier 1 capability before falling back to Tier 2.
- [ ] `install.sh` regenerates the prompt from source on every persistent install.
