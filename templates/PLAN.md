# PLAN: [Topic]

<!--
  PLAN documents are structured procedures for /core execution.
  They should be professional, complete, and ready to hand off.

  Iterate in your sketch; commit in the plan.

  See: workflows/plan.md for the full protocol specification.
-->

## Goal

<!-- One paragraph: what we're doing and why. Be specific. -->

## Constraints

<!-- Non-negotiable external limits. Different from Out of Scope (our choice). -->

- ...

## Decisions

<!-- Key decisions with rationale. Keep rationale brief; detailed analysis belongs in the sketch. -->

| Decision | Choice | Rationale |
| :------- | :----- | :-------- |
| ...      | ...    | ...       |

## Risks & Assumptions

<!--
  From the CHALLENGE phase. Don't sanitize — if a risk is CRITICAL, say so.
  Every assumption should be marked validated or unvalidated.
  If CHALLENGE revealed the direction was flawed, that should be visible here.
-->

| Risk / Assumption | Severity | Status | Mitigation / Evidence |
| :---------------- | :------- | :----- | :-------------------- |
| ...               | ...      | ...    | ...                   |

## Open Questions

<!--
  Knowledge gaps identified during planning.
  If you filled the gap, note how. If it remains open, note what research is needed.
  Gaps that could invalidate the design must be resolved before COMMIT.
-->

- ...

## Scope

### In Scope

- ...

### Out of Scope

- ...

## Phases

<!--
  Phases are nested task lists using checkboxes. Depth should match complexity.
  Each phase should be independently valuable (Phase 1 useful even if Phase 2 fails).
  Each phase should be executable as a bounded /core invocation.

  Use checkboxes (- [ ]) for deliverables so /core can check them off as completed.
  This makes plan progress visible to anyone reading the document.
-->

1. **Phase 1: [Name]** — [objective]
   - [ ] Deliverable 1
   - [ ] Deliverable 2

2. **Phase 2: [Name]** — [objective]
   - [ ] Deliverable 1
     - [ ] Sub-task if needed
     - [ ] Sub-task if needed
   - [ ] Deliverable 2

## Verification

<!-- Testable checkpoints. How do we know we're done? -->

- [ ] Checkpoint 1
- [ ] Checkpoint 2

## Technical Debt

<!--
  Accumulated during CORE execution. This section is the canonical,
  publicly visible record of debt introduced during this plan's lifecycle.
  MEDIUM+ items from JUSTIFICATION.DEBT blocks must be recorded here
  with explicit follow-up plans. This section is empty at plan creation
  and populated during execution.
-->

| Item | Severity | Why Introduced | Follow-Up | Resolved |
| :--- | :------- | :------------- | :-------- | :------: |

## Deviation Log

<!--
  Populated during CORE execution whenever reality diverges from the plan.
  Every JUSTIFICATION.SCOPE.DELTA that is not UNCHANGED should have a
  corresponding entry here. This is the canonical, at-a-glance record of
  how execution differed from what was planned — complementary to the
  sketch's real-time execution notes and the retrospective's post-hoc
  synthesis.

  This section is empty at plan creation and populated during execution.
-->

| Commit | Planned | Actual | Rationale |
| :----- | :------ | :----- | :-------- |

## Retrospective

<!--
  Filled in after execution is complete. This is the committed, public record
  of lessons learned — distilled from execution notes in the sketch lifecycle
  journal. The sketch captures real-time observations; the plan gets the
  durable takeaways that future agents and humans should know about.

  Not every plan warrants a full retrospective. But if the plan diverged,
  if unexpected debt accumulated, or if you noticed a pattern that future
  cycles should know about — write it down. The cost of overdocumenting is
  negligible; the cost of losing hard-won lessons is severe.
-->

### Process

- Did the plan hold up? Where did we diverge and why?
- Were the estimates/appetite realistic?
- Did CHALLENGE catch the risks that actually materialized?

### Outcomes

- What unexpected debt was introduced?
- What would we do differently next cycle?

### Pipeline Improvements

- Should any axiom/persona/workflow be updated based on this experience?

## References

<!--
  Sketch contains the full thought chain (ideation, planning, execution notes).
  It may not be available to all users (sketches can be kept private).
  Plan should be self-sufficient, but linking enables deeper archaeology.
-->

- Charter: `docs/charters/[initiative].md` _(if applicable)_
- Sketch: `.sketches/[topic].md`
- ADR: `docs/adr/[number].md` _(if applicable)_
