---
name: continue
description: |
  SOP for resuming C.O.R.E. execution with invariant reinforcement.
  Trigger when:
  - Resuming work after a commit boundary halt or context drift.
  - Prompt contains: /continue, continue execution, execution invariants, review block, justification block.
---
 
# Core Continue (Resume Sequence Walk)
 
The execution plan has been approved. Resume the sequence walk and implement changes according to the discrete trajectory.
 
---
 
## Execution Invariants
 
As you execute the sequence, you MUST:
 
1. **Closed-Loop Verification Loop (TDD-First)**: For each planned transition, execute code edits and run the verification suite (compilers, test runners, linters):
    - **TDD Formulation**: Formulate and write the test assertion mapping to `INVARIANT` in `TEST_TARGET`.
    - **Baseline Check**: Run `VALIDATOR` to obtain the baseline error differential $\Delta E_0$ (which must fail, confirming the test is non-trivial).
    - **Generation**: Implement code edits at `IMPL_TARGET` to satisfy `IMPL_DELTA`.
    - **Deterministic Evaluation**: Execute `VALIDATOR` to get $\Delta E_k$.
    - Formulate and apply corrective edits ($\Delta \mathbf{S}_{k+1}$) to minimize the error vector $\Delta E_k$. Repeat up to a cap of 3-5 iterations.
    - If the loop fails to converge or hits a contradiction, transition to `CLARIFY` and halt.
2. **Verify each step** against its `INVARIANT` target and output verification evidence.
3. **Commit Gate**: Commit automatically if `CONTROL_MODE: AUTOMATIC` (and authorized). Otherwise, halt.
4. **Never execute git commit** unless `CONTROL_MODE: AUTOMATIC` is set and all verification steps pass.
5. **Output artifacts visibly** — code, messages, and verification in final response (not hidden).
6. **Update and commit sketch** — per the planning persona's Sketch Commit Discipline and Lifecycle Journal sections.
7. **Evaluate strategic drift** — at commit boundaries, if `JUSTIFICATION.SCOPE.DELTA != UNCHANGED`, assess whether the deviation is tactical or strategic per the planning persona's **Strategic Escalation** section. If strategic, emit an ESCALATION block and HALT.
 
You must NOT:
 
- Add fields to the CORE-YAML grammar (except permitted fields in SCHEMA_RIGIDITY)
- Proceed past a commit boundary without explicit `/continue` (unless `CONTROL_MODE: AUTOMATIC` is active)
- Execute `git commit` without explicit authorization (`CONTROL_MODE: AUTOMATIC`) and passing verification
- Push through verification failures that cannot be resolved in the Closed-Loop Verification Loop — revert to CLARIFY instead
- Skip sketch updates at commit boundaries — the sketch is the decision record
- Implement code edits without formulating and verifying the baseline test failure first (TDD constraint)
 
---
 
## At Commit Boundaries
 
- **Closed-Loop Verification Loop**: Before concluding the work at any commit boundary, the agent MUST run the verification suite (compilers, test runners, linters, etc.).
- **Iterative Refinement Loop**: Run a manual self-audit (TDD completeness, Hickey complecting checks, Lowy temporal volatility alignment, code styling). If checks fail or code quality score is less than 1.0, apply corrective edits and re-run verification.
- **Auto-Commit Execution**:
  - If `CONTROL_MODE: AUTOMATIC` (and credentials/command permissions are active):
    1. Update the sketch notes in `.sketches/[topic].md`, then `git add` and `git commit` inside the `.sketches/` subrepo.
    2. Output the `REVIEW` block, `JUSTIFICATION` block, and conventional commit message.
    3. Execute `git add [modified files]` and `git commit -m "[message]"` directly.
    4. Automatically proceed to the remaining PLAN steps without halting.
  - If `CONTROL_MODE: MANUAL` (or not specified):
    1. Output in this order, then **HALT**:
       - REVIEW block (structured output of self-review findings: SCORE, FINDINGS with SEVERITY/ACTION/DETAIL)
       - Sketch update — append execution notes to `.sketches/[topic].md`, then `git add` and `git commit` in the `.sketches/` subrepo
       - JUSTIFICATION block — approach, scope delta, API impact, debt
       - Commit message — [conventional format](file:///var/home/nrd/git/github.com/nrdxp/predicate/skills/commit-hygiene/SKILL.md) (conforming to the commit-hygiene skill guidelines)
       - REMAINING STEPS — re-output remaining PLAN steps
    2. **Await explicit approval** before proceeding.
 
---
 
## Context Recovery
 
If sequence context has drifted (long execution, many steps), reload boundary conditions in this order:
 
1. **Plan** — re-read `docs/plans/[topic].md` for current goals and phases.
2. **Sketch** — if available at `.sketches/[topic].md`, review for decision history and execution notes.
3. **ADR** — check `docs/adr/` for relevant architectural decisions.
4. **Skills** — all foundational rules and active language skills.
 
---
 
## Lexicon Translation Matrix
 
| Psychological Term | Control-Theoretic / Physical Translation | Operational Meaning in the Loop |
| :--- | :--- | :--- |
| "Thinking" / "Reasoning" | Stochastic search / sequence generation | Autoregressively walking the discrete token topology. |
| "Understanding" / "Knowing" | Initial Boundary Condition saturation | Having a fully specified context vector (uncertainty = 0.0). |
| "Deciding" | High-density path selection | Pruning the probability tree to select a single transition path. |
| "Hallucination" / "Error" | Trajectory drift / stochastic divergence | Compounding errors in open-loop generation. |
| "Reviewing" / "Auditing" | Deterministic / manual state verification | Calculating the error differential against constraints. |
| "Fixing bugs" | Trajectory correction | Applying feedback ($\Delta \mathbf{S}$) to minimize the error vector ($\Delta E$). |
| "Halt" / "Stop" | Phase-space freeze | Pausing autoregressive generation to await boundary modifications. | boundary modifications. |