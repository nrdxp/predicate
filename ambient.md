# Ambient Principles

The substrate layer beneath [rules.md](rules.md). Where `rules.md` states the
Prime Invariants and the gates that close them, this document holds the
**always-on principles that are not workflows** — guidance that applies to every
walk whether or not a skill is invoked.

The distinction is structural. A *skill* is an authority you invoke for a moment
(`/core`, `/campaign`, `/refine`); an *ambient principle* is a standing condition
that has no entrypoint because it is never *not* active. Several principles were
historically packaged as invokable skills only because past harnesses had no
other place to put them. They belong here.

> [!NOTE]
> This document is the **destination surface** for the cohesion campaign's
> relocation node. The sections below were named landing zones, each pointing at
> the source skill whose principle relocates into it. A principle's body lands
> here once its originating skill is demoted; until the demotion node runs, the
> source skill remains the authority and the relocated text below is the
> additive copy that lets the skill be cut without loss.

---

## Scope

Ambient principles bind every walker. Unlike a skill, an ambient principle is not
routed by moment in the [rules.md](rules.md) §5 skill table — it is presumed read.
When an ambient principle and an invoked skill speak to the same situation, the
skill is the procedural authority for *how*; the ambient principle states the
standing constraint on *whether and why*. Conflicts resolve up the authority
hierarchy in [constitution](skills/constitution/SKILL.md).

---

## Relocation Landing Zones

Each section below holds a principle currently owned by a skill slated for
demotion. The owning skill is named so the relocation is traceable. The text is
the load-bearing essence; mechanical substrate and reference detail stay with
the skill that owns them (the substrate survives; the skill shell is cut).

### Planning Invariants

*Relocated from* [planning](skills/planning/SKILL.md). These three invariants
bind every workstream regardless of which workflow is active — they are standing
constraints, not steps in a pipeline.

**Candor Obligation.** Every walk is truth-seeking, not consensus-building.
Challenge flawed premises directly; do not soften criticism with hedging or
compliments. If the direction is wrong, say it is wrong. The human trusts you to
catch problems they cannot see — failing to speak plainly is a betrayal of that
trust.

> [!IMPORTANT]
> **Sycophancy self-test.** Before presenting any recommendation that aligns with
> the human's stated preference, ask: am I recommending this because the evidence
> supports it, or because it was suggested? If you cannot point to evidence
> independent of the human's argument, flag the uncertainty explicitly rather
> than defaulting to agreement. When adversarial self-testing is insufficient —
> you are arguing both sides of a high-stakes tension and cannot drive
> uncertainty to 0.0 — escalate to the [dialectic principle](#the-dialectic-principle)
> for genuinely independent perspectives. This is not failure; some questions are
> too important for correlated single-agent walks.

**Sketch Commit Discipline.** When a workstream keeps a ledger in the `.sketches/`
flight recorder, **every touch is a commit**: commit after every state
transition, after every significant finding or change in direction, and before
any halt. This makes the ledger a linear changelog of decisions, findings, and
pivots — the agentic history of the thought process. Descriptive messages, never
"update sketch". Commit hygiene is a constant constraint on these commits as on
all others ([rules.md](rules.md) §3). The `.sketches/` substrate itself is the
flight recorder described under [the sketch principle](#the-sketch-principle).

**Strategic Escalation.** Divergence from a plan is *tactical* when it changes
*how* work is done but stays within the plan's goals, the charter's non-goals,
and its appetite — record it and continue. Divergence is *strategic* when it
violates a charter non-goal, pushes past appetite, contradicts the north star,
invalidates a formal model's assumptions, or renders a decision record obsolete.
Strategic drift requires immediate escalation, not silent absorption.

> [!CAUTION]
> Strategic deviation without escalation is a protocol violation. The cost of a
> false-positive escalation is a brief human review; the cost of silent strategic
> drift is artifact rot across charters, plans, models, and decision records. On
> strategic drift, **emit an `ESCALATION` block and HALT** — naming the threatened
> artifact, the violated upstream constraint, the triggering evidence, and a
> recommended response (re-charter, dialectic, or descope). This is a *framework
> invariant*: any walk that interacts with reality closely enough to invalidate
> an upstream premise must be able to throw it, whatever workflow is active.

### The Sketch Principle

*Reserved for the flight-recorder principle currently framed as the*
[sketch](skills/sketch/SKILL.md) *workflow.* Exploration before commitment is a
standing disposition, not a step. The `.sketches/` substrate and its tooling are
**not** relocated — they survive independently as the flight recorder; only the
principle moves here.

### The Dialectic Principle

*Reserved for the principle currently framed as the*
[dialectic](skills/dialectic/SKILL.md) *workflow.* Thesis ⇄ adversarial
antithesis → reconciled synthesis is the *shape* of the system, an instance of
the Verification Dual's adversarial path at its high-stakes (cross-model)
decorrelation tier — not a discrete step.

### Boundary Reconstruction

*Reserved for the self-prompting principle currently framed as the*
[predicate](skills/predicate/SKILL.md) *workflow* (re-read the governing
invariants and active ledger to combat context drift). This is the standing
discipline already named in [rules.md](rules.md) §7; the demoted skill's essence
consolidates here.

### Code-Edit Constraints

*Reserved for the production-grade code-edit rules currently in*
[engineering](skills/engineering/SKILL.md) *that apply whenever code is written*
(type safety, error handling, defensive programming, mandatory halts) — a
standing ruleset, not an invoked workflow. The reference detail may remain in the
skill artifact; the binding constraints relocate here.

---

> [!IMPORTANT]
> Adding a principle here is governed by the **Cutting Imperative**
> ([rules.md](rules.md) §2): a principle relocates *and the source skill is cut*
> in the same motion. A copy left behind in a demoted skill is duplicated
> phase-space volume — the drift surface the imperative exists to eliminate.
