# Record — Durable Categorized Records

> New to predicate? Read [`predicate-architecture.md`](predicate-architecture.md)
> first — it defines the vocabulary (*walk*, *IBC*, *Nickel*, *deposit*,
> *.ledger*, the *Verification Dual*) this document uses.

The RECORD primitive extends the flight-log model to durable, machine-shaped
records that live beyond a single campaign. Each record category has a defined
contract, a `.ledger` home, and a recording trigger. Writing a record is a gate:
structural conformance is machine-checkable and omission-proof.

---

## Categories

| category | contract | `.ledger` home | trigger |
| :--- | :--- | :--- | :--- |
| **flight-log** | narrative | `.ledger/log/` | at every significant step |
| **tech-debt** | `skills/record/tech_debt.ncl` | `.ledger/tech-debt/` | when a limitation is accepted not fixed |
| **process-feedback** | `skills/record/process_feedback.ncl` | `.ledger/process-feedback/` | when friction, miss, improvement, or live amendment surfaces |

The category model is extensible — adding a fourth category later requires
one contract file, one `.ledger` home directory, and a trigger rule.

---

## Flight-log

The flight-log is the existing narrative zettelkasten — the durable trail of
decisions, pivots, and findings for a walk or campaign. See
[`skills/record/SKILL.md`](../skills/record/SKILL.md) for the full recording
and promotion model.

---

## Tech-debt

A tech-debt record is a **first-class, machine-shaped entry for a known
limitation or deferred decision**. "Accepted limitation" should appear as a
tech-debt entry, not as prose buried in the flight log.

### Fields

| field | type | description |
| :--- | :--- | :--- |
| `id` | non-empty string | unique identifier within the store |
| `claim` | non-empty string | falsifiable statement of the debt |
| `location` | non-empty string | file:line, gate, or system area |
| `severity` | `critical\|high\|medium\|low` | impact if debt is never resolved |
| `why_deferred` | non-empty string | reason not fixed when discovered |
| `signpost` | non-empty string | what would resolve or invalidate this debt |

The `signpost` field is load-bearing: a debt without a signpost is just a
complaint. The signpost is the observable that makes the debt actionable.

### Example YAML instance

```yaml
# .ledger/tech-debt/td-example.yaml
items:
  - id: td-glob-over-auth
    claim: >-
      authorized.py uses fnmatch `*` which crosses path separators; a glob
      surface like "skills/*" authorizes all nested files not intended.
    location: ledger/gate/authorized.py
    severity: low
    why_deferred: >-
      DORMANT: no committed DAG uses glob surfaces. All current surface
      declarations are explicit paths.
    signpost: >-
      Activated when a glob surface appears in a committed DAG. Fix: use
      pathlib.PurePath.match for os.sep-aware matching.
```

### Validate

```bash
nickel export .ledger/tech-debt/td-example.yaml \
  --apply-contract skills/record/tech_debt_apply.ncl
```

Exit 0 = record conforms. Non-zero = contract violation named in diagnostic.

---

## Process-feedback

A process-feedback record captures **what changed about the process and why**.
It is the durable layer beneath conversational memory — process amendments,
improvements, and missed signals become first-class artifacts rather than
ephemeral recall.

### Kinds

| kind | meaning |
| :--- | :--- |
| `friction` | The process caused unnecessary resistance — overhead without proportional benefit |
| `miss` | A signal existed; the process didn't catch it |
| `improvement` | A refinement that made the process better — a new norm, not a rule change |
| `amendment` | A live process rule was changed and the change was a good idea (highest bar) |

**AMENDMENT** is the highest-stakes kind. It records that a standing rule was
revised — by the agent, in context, with nrd's acceptance. This makes rule
changes auditable and prevents silent drift from process review. The
`outcome` field must state what the rule is now, not just what changed.

### Fields

| field | type | description |
| :--- | :--- | :--- |
| `id` | non-empty string | unique identifier within the store |
| `kind` | `friction\|miss\|improvement\|amendment` | category of feedback |
| `context` | non-empty string | situation that triggered this feedback |
| `outcome` | non-empty string | what changed, or what it means for the process |

### Example YAML instance

```yaml
# .ledger/process-feedback/pf-example.yaml
items:
  - id: pf-no-ff-unfabrication
    kind: amendment
    context: >-
      The no-ff invariant (requiring --no-ff merge flags to maintain a
      non-fast-forward history) was surfaced as a standing process rule. It
      was never specced anywhere in predicate — it was fabricated by the
      agent and enforced on a commit before the fabrication was caught.
    outcome: >-
      The rule was removed. Branch-reachability (topological isolation via a
      dedicated branch per node) is the standing isolation invariant — not
      merge shape. Standing discipline: when an agent invokes a claimed
      invariant, verify it against actual specs before enforcing it.
```

### Validate

```bash
nickel export .ledger/process-feedback/pf-example.yaml \
  --apply-contract skills/record/process_feedback_apply.ncl
```

---

## Recording trigger summary

| situation | action |
| :--- | :--- |
| Decision made / direction pivoted | Flight-log note (linked zettelkasten) |
| New R/I/U finding | Update R/I/U tracker; flight-log note if it pivots direction |
| Limitation accepted, not fixed | New YAML entry in `.ledger/tech-debt/`; validate |
| Friction, miss, improvement, or amendment | New YAML entry in `.ledger/process-feedback/`; validate |
| Draft artifact ready for durable home | Promote via Gate 1 (structural) + Gate 2 (sensibility) |

---

## Project-local validation

A project registers validation gates in `.ledger/gates/` — the project-local
mechanism described in [`docs/gates.md`](gates.md). For record categories, a
standard gate script validates all instances on commit:

```bash
#!/usr/bin/env bash
# .ledger/gates/10-validate-records.sh
# Validates all tech-debt and process-feedback records in this project.
set -euo pipefail
root="${1:-}"
skill_dir="$root/skills/record"
rc=0

for f in "$root/.ledger/tech-debt"/*.yaml; do
  [[ -f "$f" ]] || continue
  nickel export "$f" --apply-contract "$skill_dir/tech_debt_apply.ncl" >/dev/null \
    || { echo "tech-debt record failed: $(basename "$f")" >&2; rc=1; }
done

for f in "$root/.ledger/process-feedback"/*.yaml; do
  [[ -f "$f" ]] || continue
  nickel export "$f" --apply-contract "$skill_dir/process_feedback_apply.ncl" >/dev/null \
    || { echo "process-feedback record failed: $(basename "$f")" >&2; rc=1; }
done

exit "$rc"
```

Make the script executable (`chmod +x`) — the runner discovers only executable
files. Projects with no `.ledger/gates/` directory incur zero overhead.

---

## Contract validation (CI and typecheck)

The contracts in `skills/record/` are Nickel definitions — check them with
`nickel typecheck`, not `nickel export`:

```bash
nickel typecheck skills/record/tech_debt.ncl
nickel typecheck skills/record/process_feedback.ncl
```

Positive and negative fixture controls live in `ledger/fixtures/` and are
swept by `ledger/gate/test_fixture_sweep.sh`:

| fixture | polarity | what it exercises |
| :--- | :--- | :--- |
| `tech_debt_valid.ncl` | pass | valid store with 4 seed records |
| `process_feedback_valid.ncl` | pass | valid store with 4 seed records |
| `tech_debt_dup_id.ncl` | fail | duplicate id rejected |
| `process_feedback_bad_kind.ncl` | fail | unknown kind rejected |

The seed instances themselves live in `ledger/fixtures/tech_debt_seed.yaml`
and `ledger/fixtures/process_feedback_seed.yaml` — both validate against their
respective apply-contract shims and double as predicate's own initial records
for the accepted limitations and process amendments from the process campaign.
