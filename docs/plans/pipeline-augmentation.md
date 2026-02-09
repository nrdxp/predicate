# PLAN: Pipeline Augmentation (Research-Backed)

## Goal

Augment the `/charter → /sketch → /plan → /core` pipeline with research-backed refinements and a new `/charter` workflow, based on cross-referencing against Shape Up, Working Backwards, DDD, ADR-E, and SRE literature. Nine changes total: eight surgical edits to existing files and one new workflow.

## Constraints

- Language must be open-source native — no corporate/product-management vocabulary
- Changes must be general-purpose, not DDD/enterprise-specific
- Must not break existing state machines or YAML grammars
- `/charter` must be optional, not a mandatory pipeline prerequisite
- All changes must be compatible with how the pipeline is actually used (per sketch history)

## Decisions

| Decision                | Choice                                    | Rationale                                                                                       |
| :---------------------- | :---------------------------------------- | :---------------------------------------------------------------------------------------------- |
| Strategic layer naming  | `/charter` over `/vision` or `/pitch`     | "Charter" is open-source native — a founding document. "Vision" is vague; "pitch" is corporate. |
| Charter complexity      | No state machine                          | A charter frames intent — it's a declaration, not a process. Divergence happens in sketches.    |
| OUTCOME block placement | EVALUATION section in sketch grammar      | Keeps it lightweight; doesn't force value-narrative on exploratory phases.                      |
| Appetite location       | SCOPE state definition in plan.md (prose) | Avoids grammar changes; communicates the _mindset_ rather than adding a field.                  |
| Domain coherence        | CHALLENGE technique bullet                | General enough for all projects; DDD-heavy projects can use a persona.                          |
| Debt tracking           | Hybrid sketch notes + plan checkpoint     | Committed via sketch; aggregated via plan. No standalone DEBT.md.                               |
| Retrospective           | Sketch lifecycle section                  | Not a separate workflow. Final chapter of the sketch's story.                                   |
| Cross-cycle context     | Planning persona guidance                 | Low-overhead — just a reminder to check prior work.                                             |
| Phasing                 | Two phases (refinements, then charter)    | Independent concerns; smaller review units.                                                     |

## Risks & Assumptions

| Risk / Assumption                                                          | Severity | Status      | Mitigation / Evidence                                                              |
| :------------------------------------------------------------------------- | :------- | :---------- | :--------------------------------------------------------------------------------- |
| Cross-file consistency after many edits                                    | MEDIUM   | Unvalidated | Grep verification after each phase to ensure no stale references or contradictions |
| OUTCOME block could feel bureaucratic for small sketches                   | LOW      | Accepted    | Block is 2 fields — minimal overhead. Agent can use "N/A" for trivial work         |
| Appetite guidance too vague (prose vs. grammar)                            | MEDIUM   | Accepted    | Start with prose; if agents consistently ignore it, promote to grammar field later |
| /charter scope could expand                                                | MEDIUM   | Mitigated   | Explicit non-goals in charter workflow; constrain to single-document output        |
| Retrospective section won't be used if agents don't reach end of lifecycle | LOW      | Accepted    | True for all lifecycle guidance — can't force completion                           |
| CHALLENGE technique list getting long                                      | LOW      | Accepted    | Techniques are a menu, not a checklist — agents pick what's relevant               |

## Open Questions

- None. Both adversarial rounds resolved open questions. Research was extensive (11+ papers/methodologies reviewed through NotebookLM).

## Scope

### In Scope

**Phase 1 — Existing Pipeline Refinements:**

- Surgical edits to sketch.md, plan.md, core.md, planning.md persona, and PLAN.md template

**Phase 2 — New `/charter` Workflow:**

- New workflow file, README update

### Out of Scope

- Redesigning existing state machines
- Adding code execution to /sketch (Spikes proposal — rejected)
- DDD-specific `/domain` workflow (rejected — use persona if needed)
- Standalone `/retro` workflow (absorbed into sketch lifecycle)
- Creating a formal DEBT.md ledger
- Changing YAML grammar field types or state names

## Phases

1. **Phase 1: Pipeline Refinements** — surgical edits to existing workflow and persona files
   - [x] Add `OUTCOME` block to sketch.md EVALUATION grammar
   - [x] Add ABORT-as-value framing to sketch.md
   - [x] Add appetite-awareness to plan.md SCOPE state definition
   - [x] Add Domain Coherence Check bullet to plan.md CHALLENGE techniques
   - [x] Add ADR traceability line to plan.md ADR_WHEN_WARRANTED directive
   - [x] Add `Debt:` field to planning.md execution notes template
   - [x] Add RETROSPECTIVE section to planning.md lifecycle journal
   - [x] Add cross-cycle context guidance to planning.md
   - [x] Add MEDIUM+ debt checkpoint to PLAN.md template
   - [x] Add MEDIUM+ debt sketch-recording guidance to core.md

2. **Phase 2: `/charter` Workflow** — new workflow for multi-cycle strategic framing
   - [x] Create charter.md — grammar, purpose, usage guidance
   - [x] Create templates/CHARTER.md — committed artifact template
   - [x] Add Charter cross-reference to templates/PLAN.md
   - [x] Update README.md workflow table and pipeline documentation

## Verification

- [x] `rg "OUTCOME" workflows/sketch.md` returns the new block
- [x] `rg "worth the investment" workflows/plan.md` returns the scope guidance
- [x] `rg "Domain Coherence" workflows/plan.md` returns the technique bullet
- [x] `rg "ALTERNATIVES_REJECTED" workflows/plan.md` returns the ADR traceability mandate
- [x] `rg "Debt:" personas/planning.md` returns the execution notes field
- [x] `rg "RETROSPECTIVE" personas/planning.md` returns the lifecycle section
- [x] `rg "prior work" personas/planning.md` returns the cross-cycle guidance
- [x] `rg "ABORT" workflows/sketch.md` returns the reframing language
- [x] `rg -i "debt" templates/PLAN.md` returns the verification checkpoint
- [x] `rg -i "debt" workflows/core.md` finds the new guidance
- [x] `workflows/charter.md` exists with complete grammar and documentation
- [x] README.md workflow table includes `/charter`
- [x] No stale or contradictory references introduced: `rg "customer|product.engineering|PR.FAQ|betting|cool.down" workflows/ personas/` returns zero results

## Technical Debt

| Item     | Severity | Why Introduced | Follow-Up |
| :------- | :------- | :------------- | :-------- |
| _(none)_ |          |                |           |

## Retrospective

### Process

- **Plan held up well.** Phase 1 delivered exactly as scoped (10 surgical edits in 4 commits). Phase 2 expanded from 2→3 commits after discovering that the charter needs a committed artifact template and plan cross-reference — a genuine improvement surfaced by human review during execution.
- **Estimates were realistic.** Phase 1: 4 commits estimated, 4 delivered (+2 correction commits for debt tracking location). Phase 2: 2 estimated, 3 delivered. All well within single-session appetite.
- **CHALLENGE caught the right risks.** "Cross-file consistency after many edits" (MEDIUM) materialized — the retrospective found 3 stale references (README "three phases", planning.md "three workflows", README "can't skip ahead"). Corporate vocabulary risk was verified at each commit boundary via `rg`.
- **Verification command had a bug.** The `rg "appetite"` check was written during planning but the actual implementation used "worth the investment" prose — the word "appetite" never appeared. Corrected to `rg "worth the investment"`.

### Outcomes

- **No debt introduced.** All changes are additive documentation.
- **What we'd do differently:**
  - Check off plan items _during_ execution, not after — the PLAN_PROGRESS directive (#14) we added in Phase 1 exists for exactly this reason
  - Test verification commands when writing them, not after execution
  - Template/artifact decisions (CHARTER.md, plan cross-ref) should surface during `/plan`, not mid-execution
  - Retrospective sections should have been in the plan template from the start — the sketch captures real-time notes, but durable lessons belong in the committed plan

### Pipeline Improvements

- **Flexible entry language is now canonical.** The pipeline is not rigidly sequential — entry point depends on scope. This framing should be the default anywhere the pipeline is introduced.
- **Plan template now includes Retrospective section** — added during this retrospective as a self-referential fix. Same pattern as debt tracking: durable records belong in committed documents, not gitignored sketches.

## References

- Sketch: `.sketches/2026-02-08-pipeline-augmentation.md`
