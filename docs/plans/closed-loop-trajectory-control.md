# PLAN: Closed-Loop Trajectory Control
 
## Goal
 
Refactor Predicate's workflows (`core`, `continue`, `spec`, `model`), global rules (`engineering`), and verification acknowledgments (`predicate`) to transition the entire pipeline from open-loop heuristic processes to a unified closed-loop feedback controller. This connects specifications and models directly to test invariants (TDD), specifies mathematically rigorous sequence optimization loops, and implements automated commit-and-continue cycles as the default execution pathway with failure-to-converge halting as the fallback gate.
 
## Constraints
 
- Violently strip all anthropomorphic and psychological terminology from the workflow instructions.
- Evolve the CORE-YAML metadata grammar to use control-theoretic fields (`CONTROL_MODE`, `UNCERTAINTY`, `STABILITY`), as compatibility is explicitly not a concern.
- Retain absolute user sovereignty: if verification fails to converge, or if a strategic contradiction is met, the agent must halt and ask.
- Retain conventional commit message hygiene constraints.
 
## Decisions
 
| Decision | Choice | Rationale |
| :--- | :--- | :--- |
| **Integrated TDD Loop** | Specifications and Models must output explicit test invariants and transition assertions | Connects the design phase directly to the deterministic test validator in the execution phase. |
| **CONTROL_MODE field** | `CONTROL_MODE: [MANUAL | AUTOMATIC]` in CORE-YAML metadata | Enables declarative control over automated execution cycles. |
| **Error Feedback Loop** | Mathematically rigorous loop in `EXECUTE` states of `core` and `continue` | Dictates how the agent treats compiler/test output as the error differential and modifies code to force convergence. |
| **Automated Commit Gate** | If `CONTROL_MODE: AUTOMATIC`, execute commits and proceed automatically | Eradicates boundary ceremony for authorized CLI agents while maintaining safety through verification loops. |
| **Acknowledgment Coherence** | Conditionalize refresh completion rules in `predicate.md` | Prevents false rule conflicts during context reloads. |
 
## Risks & Assumptions
 
| Risk / Assumption | Severity | Status | Mitigation / Evidence |
| :--- | :--- | :--- | :--- |
| Auto-commit loops could run indefinitely on complex errors | MEDIUM | Unvalidated | Impose a hard limit of $N$ iterations (default 3-5). If exceeded, halt and transition to `CLARIFY`. |
| Weak or missing tests could allow buggy code to autocommit | HIGH | Unvalidated | Mandate that auto-commit is strictly forbidden unless a deterministic test suite or verification script is present. |
 
## Scope
 
### In Scope
 
- **Phase 1: Design Workflows Refactoring**:
   - Update `skills/spec/SKILL.md` to map normative constraints to Test Invariants.
   - Update `skills/model/SKILL.md` to map formal state spaces to Transition Assertions.
- **Phase 2: Execution Workflows Refactoring**:
   - Update `skills/core/SKILL.md` and `skills/continue/SKILL.md` to define the Closed-Loop Verification Loop and the `CONTROL_MODE` execution path, rewritten in control-theoretic language.
- **Phase 3: Global Rules & Acknowledgment**:
   - Update `skills/engineering/SKILL.md` §11 to allow conditional auto-commits under `CONTROL_MODE: AUTOMATIC`.
   - Update `skills/predicate/SKILL.md` to conditionalize halting and git commit restrictions.
- **Phase 4: Auditing & Retrospective**:
   - Run `python3 skills/doc-audit/scripts/check_docs.py .` to ensure link integrity.
 
### Out of Scope
 
- Building a custom command-runner or execution daemon.
 
## Phases
 
1. **Phase 1: Design Workflows (Spec and Model)** — Connect design to verification
   - [x] Refactor `skills/spec/SKILL.md` to define constraints as Test Invariants in non-anthropomorphic language.
   - [x] Refactor `skills/model/SKILL.md` to define state spaces as Transition Assertions in non-anthropomorphic language.
 
2. **Phase 2: Execution Workflows (Core and Continue)** — Define the closed-loop optimization
   - [x] Refactor `skills/core/SKILL.md` to add `CONTROL_MODE`, define the closed-loop error-feedback loop, and specify autocommit execution, using control-theoretic terminology.
   - [x] Refactor `skills/continue/SKILL.md` to match core invariants and commit boundaries rules.
 
3. **Phase 3: Global Invariants (Engineering and Predicate)** — Align constraints
   - [x] Refactor `skills/engineering/SKILL.md` §11 to permit conditional auto-commit.
   - [x] Refactor `skills/predicate/SKILL.md` acknowledgment block to conditionalize halting.
 
4. **Phase 4: Auditing & Retrospective** — Run quality control
   - [x] Run link audit: `python3 skills/doc-audit/scripts/check_docs.py .`
   - [x] Verify formatting of all edited skills.
 
## Verification
 
- [x] `skills/spec/SKILL.md` maps constraints to Test Invariants.
- [x] `skills/model/SKILL.md` maps state spaces to Transition Assertions.
- [x] `skills/core/SKILL.md` and `skills/continue/SKILL.md` describe the closed-loop validation loop and `CONTROL_MODE`.
- [x] `skills/engineering/SKILL.md` allows conditional autocommits.
- [x] `skills/predicate/SKILL.md` has conditional refresh completion.
- [x] Document audit script runs with zero errors.
 
## Technical Debt
 
| Item | Severity | Why Introduced | Follow-Up | Resolved |
| :--- | :--- | :--- | :--- | :---: |
| None | | | | |
 
## Deviation Log
 
| Commit | Planned | Actual | Rationale |
| :--- | :--- | :--- | :--- |
| | | | |
 
## Retrospective
 
### Process
The transition to closed-loop trajectory control proceeded through systematic refactoring of design, execution, and global verification rules. The process successfully integrated a TDD validation constraint directly derived from specifications and models. No significant process bottlenecks were encountered, and link-audits confirmed zero broken linkages.
 
### Outcomes
- All psychological terminology was purged.
- Spec, Model, Core, Continue, Engineering, and Predicate skills were refactored to align with control-theoretic operations.
- The `CONTROL_MODE` mechanism and closed-loop validation error relaxation loops are fully active.
- Verification and doc audits are 100% passing.
 
### Pipeline Improvements
Transitioning from subjective/anthropomorphic prompts to explicit error-differential verification loops provides deterministic boundaries that prevent stochastic drift and enforce strict testing invariants before code staging.
 
## References
 
- Sketch: `.sketches/2026-06-04-closed-loop-trajectory-control.md`
