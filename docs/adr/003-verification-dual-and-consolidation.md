# ADR-003: The Verification Dual and the Cohesion Consolidation

**Status:** ACCEPTED

**Date:** 2026-06-19

---

## Context

Predicate grew historically as a set of skills, each added when a need
appeared. Two structural problems followed from that growth.

First, **verification was scattered and partly honor-system.** Several skills
each carried a piece of the same idea: `refine`'s contraction loop and
hostile-maintainer review, a `dialectic` workflow's cross-model decorrelation,
`campaign` SURVEY's multi-boundary sweep, the one-shot skepticism rule. There
was no single statement of *how a condition is closed*, and nothing forced a
machine-checkable property to be checked by a machine rather than asserted by
the agent that produced it. A gate an agent must remember to invoke is not a
gate.

Second, **the skill set complected principle with procedure.** Dispositions
that are never *not* active — explore before you commit, challenge flawed
premises, rebuild your boundary when context drifts — were packaged as invokable
workflows (`sketch`, `dialectic`, `planning`, `predicate`) only because past
harnesses had no other place to put them. Strategic-framing workflows (`plan`,
`charter`) duplicated what a campaign's boundary and planning pass already
produce. The result was redundant surface: more skills to load, more places for
the same rule to drift out of agreement with itself. In the system's own terms,
unjustified artifacts are excess phase-space volume — drift surface.

## Decision

Adopt the **Verification Dual** as the system's core invariant, and consolidate
the skill set by cutting, demoting, and thinning against it.

### The Verification Dual — verify, then trust

Every condition that must hold is closed by the strongest applicable evaluator,
and exactly one of two complementary paths closes it:

- **Symbolic path.** If a deterministic evaluator exists or can be built, it
  *must* be used. The evaluator hierarchy, strongest first:
  `proof > type > property test > example test > linter`. The evaluator's exit
  code is the verdict; the agent's self-report is ignored.
- **Adversarial path.** If no deterministic evaluator can exist, the condition
  is closed by adversarial review from context-free agents in decorrelated
  boundaries. Decorrelation is load-bearing: a single reviewer shares the
  generator's attractor basin, so blind spots coincide; reviewers in different
  basins have non-overlapping blind spots whose union covers the artifact.

Both paths iterate to a fixed point against error feedback. The adversarial path
also audits its own classification — "could this have been machine-checked?" —
so the soft path self-polices back toward the hard path and never becomes an
escape hatch. Human review is the escalation slot only, invoked when
decorrelated reviewers fail to converge.

The Dual becomes Prime Invariant 1 in [rules.md](../../rules.md), and a new
Prime Invariant — the **Cutting Imperative**, gated by a `molten`/`stable`
maturity flag — makes the consolidation below a standing disposition rather than
a one-time event.

### The consolidation

Audited grounded against the actual skill files (not their self-descriptions),
the 40 skills resolve three ways:

- **Keep (28).** The spine (`boundary`, `campaign`), the worker disciplines
  (`core`, `refine`), the gates, the lenses, the doc stack, the formal cluster,
  the audits, the languages, and the remaining tool and reference skills.
- **Demote to the ambient layer (6).** `planning`, `sketch`, `dialectic`, and
  `predicate` are principles, not workflows — they relocate into
  [ambient.md](../../ambient.md). `engineering`'s binding code-edit constraints
  relocate there too (the skill survives as reference elaboration). `doc-audit`'s
  prose guidance folds into `documentation` while its script is kept.
- **Cut (5).** `plan` and `charter` are subsumed by the campaign IBC and its
  planning pass; `plan-review` folds into RECONCILE/CLOSE; `continue` folds into
  the long-horizon self-prompting rule; `personalization` folds into the ambient
  naming convention.

A demoted principle leaves no duplicate copy: a skill whose *entire* load is the
principle is cut outright; a skill that also carries reference detail is
*thinned* — the principle deferred to the ambient layer, only the elaboration
retained. This is the Cutting Imperative applied to the skill set.

## Consequences

### Positive

- **One decision rule at every gate.** "How is this condition closed?" has a
  single answer, and a machine-checkable property can no longer be closed by
  assertion.
- **Self-policing soft path.** Because the adversarial path audits its own
  classification, the symbolic path is the default and the soft path cannot
  silently absorb work that a gate could decide.
- **Less drift surface.** Fewer skills, no principle stored in two places, and a
  standing imperative to keep cutting as the system matures.
- **Principles bind unconditionally.** Moving always-on dispositions to the
  ambient layer means they apply whether or not a skill is invoked, instead of
  depending on the right workflow being triggered.

### Negative

- **The ambient layer is presumed read.** A principle with no entrypoint binds
  only if `ambient.md` is loaded alongside `rules.md`; the layer trades
  discoverability-by-invocation for unconditional applicability.
- **The adversarial path costs tokens.** Decorrelated, context-free review is
  more expensive than a single self-review, and is reserved for conditions no
  evaluator can decide.
- **`molten` defaults to aggressive change.** Pre-1.0, the default stance is
  refactor-and-cut, which moves faster but assumes a mostly-machine-authored
  base where amend-only caution is itself a defect.

---

## Alternatives Considered

| Alternative | Reason Rejected |
| :---------- | :-------------- |
| Keep verification distributed across skills | No single statement of how a condition is closed; the same rule drifts out of agreement with itself across skills, and nothing forces a machine-checkable property to be machine-checked. |
| Keep `sketch`/`dialectic`/`planning` as workflows | They are standing dispositions, not steps; gating them behind an entrypoint means they apply only when the right workflow is invoked, which is exactly when a drifting walk fails to invoke them. |
| Amend-only, never cut | In a work-in-progress, mostly-machine-authored repository, treating the structure as human-vetted and immutable preserves drift surface; the Cutting Imperative names this as a defect. |
| One ADR per cut skill | The cuts share one rationale (the Cutting Imperative measured against the Dual); a single record states the principle once rather than repeating it per skill. |

---

## References

- Rules: [rules.md](../../rules.md) — Prime Invariants 1 (the Dual) and 3 (the Cutting Imperative)
- Ambient layer: [ambient.md](../../ambient.md) — the demoted principles' home
- Orchestration protocol: [orchestration-protocol.md](../orchestration-protocol.md)
- Chronicle: [chronicle.md](../chronicle.md)
- Related ADRs: [ADR-002](002-multi-boundary-subagent-sweeps.md) (the adversarial path's sweep mechanism)
