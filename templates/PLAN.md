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
  Phases are nested task lists. Depth should match complexity.
  Each phase should be independently valuable (Phase 1 useful even if Phase 2 fails).
  Each phase should be executable as a bounded /core invocation.
-->

1. **Phase 1: [Name]** — [objective]
   - Deliverable 1
   - Deliverable 2

2. **Phase 2: [Name]** — [objective]
   - Deliverable 1
     - Sub-task if needed
     - Sub-task if needed
   - Deliverable 2

## Verification

<!-- Testable checkpoints. How do we know we're done? -->

- [ ] Checkpoint 1
- [ ] Checkpoint 2

## References

<!--
  Sketch contains the full thought chain (ideation, planning, execution notes).
  It may not be available to all users (sketches can be kept private).
  Plan should be self-sufficient, but linking enables deeper archaeology.
-->

- Sketch: `.sketches/[topic].md`
- ADR: `docs/adr/[number].md` _(if applicable)_
