# PLAN: Refine Git Worktree Flow and Hostile Maintainer Review

## Goal

Refine the `/refine` workflow skill (`skills/refine/SKILL.md`), the refinement report template (`templates/REFINE.md`), and the global trajectory rules (`rules.md`) to integrate a tighter git worktree lifecycle, a formal Pull Request-style review process involving Hostile Maintainer subagents, and active architectural documentation alignment.

## Constraints

- Follow commit-hygiene guidelines strictly (summary <= 50 characters, body/footer <= 72 characters).
- Maintain history linearity and git-history-invariance (no rebasing/amending on main or active attempt branches during execution).
- All relative documentation links must resolve correctly.

## Decisions

| Decision | Choice | Rationale |
| :--- | :--- | :--- |
| **New REVIEW State** | Add a formal `REVIEW` state between `SWEEP` and `REPORT` | Decouples functional correctness verification (linter/tests) from architectural design critique. |
| **Hostile Maintainers** | Implement 3 distinct Maintainer subagent personas | Simulates real-world code review dynamics with expert, nitpicking codebase owners. |
| **REVIEW_LEDGER Schema** | Define an append-only ledger for PR reviews | Provides a structured, auditable history of comments and refiner responses (commits/justifications). |
| **Tighter Worktree Cleanup** | Mandate `git worktree remove --force` in both success and failure exit states | Eliminates the risk of dangling worktrees polluting the host environment on halts. |
| **Active Doc Alignment** | Integrate active architectural doc updates and verification | Ensures design changes do not drift from documentation (READMEs, ADRs, `/docs`). |

## Risks & Assumptions

| Risk / Assumption | Severity | Status | Mitigation / Evidence |
| :--- | :--- | :--- | :--- |
| Hostile maintainers could nitpick infinitely (infinite review cycles) | HIGH | Unvalidated | Limit the review loop to a maximum of 3 cycles; if unresolved, transition to `HALT` or escalate to human. |
| Maintainer-requested fixes might break existing tests or linters | HIGH | Unvalidated | Mandate that the refiner must run regression tests/linters before committing any fix. |
| `git worktree remove` command fails due to file locks or untracked changes | MEDIUM | Unvalidated | Use the `--force` flag and check command exit status; log errors if they occur. |

## Open Questions

- None. All unknowns have been resolved during the SKETCH phase.

## Scope

### In Scope

- Refactoring `skills/refine/SKILL.md` to add `REVIEW` state and update git commands.
- Updating `templates/REFINE.md` to incorporate the `REVIEW_LEDGER` and maintainer sections.
- Updating `rules.md` to align with the refined worktree/review protocol.
- Performing documentation link audits.

### Out of Scope

- Modifying other workflow skills (like `/core` or `/plan`).
- Writing custom shell wrappers or automation daemons.

## Phases

1. **Phase 1: Refactor Refine Skill Definition (`skills/refine/SKILL.md`)**
   - [ ] Add the `REVIEW` state to the state transition diagram and define its procedures.
   - [ ] Integrate Hostile Maintainer personas, rubrics, and the `REVIEW_LEDGER` mechanics.
   - [ ] Update worktree setup and cleanup commands in all states.
   - [ ] Add architectural documentation management invariants to the audit, iterate, and review loops.

2. **Phase 2: Update Templates and Rules (`templates/REFINE.md` and `rules.md`)**
   - [ ] Refactor `templates/REFINE.md` to include review ledger, maintainer feedback, and worktree status fields.
   - [ ] Align `rules.md` skill routing entry for refine with the new worktree and review-centric refine protocol.

3. **Phase 3: Verification & Link Audit**
   - [ ] Run doc link audit: `python3 skills/doc-audit/scripts/check_docs.py .`.
   - [ ] Verify markdown formatting and commit hygiene.

## Verification

- [ ] `skills/refine/SKILL.md` contains the new `REVIEW` state and git worktree lifecycle commands.
- [ ] `templates/REFINE.md` contains the `REVIEW_LEDGER` schema and maintainer personas.
- [ ] `rules.md` references the refined workflow and review state.
- [ ] All tests and documentation audits run with zero errors.

## Technical Debt

| Item | Severity | Why Introduced | Follow-Up | Resolved |
| :--- | :--- | :--- | :--- | :---: |

## Deviation Log

| Commit | Planned | Actual | Rationale |
| :--- | :--- | :--- | :--- |

## Retrospective

### Process

- To be completed post-execution.

### Outcomes

- To be completed post-execution.

### Pipeline Improvements

- To be completed post-execution.

## References

- Sketch: `2026-06-09-refine-worktree-hostile-maintainer.md` (in the flight recorder, `.ledger/log/` — the `.sketches/` tree was renamed to `.ledger/`)
