---
name: core
description: |
  SOP for the micro-execution C.O.R.E. phase.
  Trigger when:
  - Implementing plan steps, managing code changes at commit boundaries, and verifying incremental progress.
  - Navigating states: Absorb, Clarify, Plan, Execute.
  - Prompt contains: /core, core workflow, absorb, clarify, execution invariants, commit boundary, verify assertion.
---
 
# C.O.R.E. Protocol v3.0: Closed-Loop Stochastic Trajectory Control (C-LTC)
 
**Context → Obstacles → Resolution → Execution**
 
This workflow defines the C.O.R.E. micro-execution phase. The objective is to guide sequence token generation through a series of discrete state transitions (Context, Obstacles, Resolution, Execution) and apply local closed-loop verification feedback loops to force trajectory convergence before committing.
 
---
 
## Scope
 
> [!IMPORTANT]
> C.O.R.E. maps a localized plan segment (typically 2-3 commit boundaries) and manages the execution trajectory. It is NOT high-level planning (that's `/plan`) and NOT exploration (that's `/sketch`). If the sequence begins exploring design alternatives or modifying the architecture, it has exited C.O.R.E. space; the walk must immediately halt.
 
## Grammar
 
```yaml
# 1. TRAJECTORY METADATA
STATUS: [ABSORB | CLARIFY | PLAN | EXECUTE]
CONTROL_MODE: [MANUAL | AUTOMATIC] # MANUAL: halt at boundaries; AUTOMATIC: autocommit and continue if tests pass.
UNCERTAINTY: [0.0-1.0]              # Residual entropy / uncertainty. Must be 0.0 to transition to PLAN/EXECUTE.
STABILITY:
  SPEC: [0.0-1.0]                   # Conformance to modal specifications
  MODEL: [0.0-1.0]                  # Conformance to state-space models
  TEST: [0.0-1.0]                   # Conformance to test invariants (TDD pass rate)
REASONING:                          # Required if UNCERTAINTY > 0.0 or any STABILITY < 1.0
  UNCERTAINTY: "Why uncertainty remains and what parameter is missing"
  STABILITY: "Why stability deviates from 1.0"
 
# 2. CONTEXT (The Initial Boundary Condition)
CTX:
  GOAL: "User's objective (quoted verbatim)"
  CONSTRAINTS:
    - "Boundary condition 1"
  FILES:
    - path/to/target/file
 
# 3. OBSTACLES (Divergence Vectors)
# Populated in CLARIFY status; forces sequence freeze
OBSTACLES:
  - "Uncertainty / contradiction 1"
 
# 4. TRAJECTORY PLAN (Discrete TDD Optimization Steps)
# Populated in PLAN/EXECUTE status
PLAN:
  RATIONALE: "Mathematical / control rationale for this trajectory"
  STEPS:
    - ID: 1
      INVARIANT: "Test assertion or property contract (TDD constraint)"
      TEST_TARGET: "tests/test_file.py::test_name"
      IMPL_TARGET: "src/file.py::function_name"
      IMPL_DELTA: "Implementation edit to satisfy the invariant"
      VALIDATOR: "pytest tests/test_file.py"
      COMMIT: true # Marks a commit boundary
```
 
---
 
## Trajectory Verification & Commit Gates
 
### 1. Closed-Loop Verification Loop (TDD-First)
For each step in the plan, execute a local optimization loop:
- **TDD Formulation**: Formulate and write the test assertion mapping to `INVARIANT` in `TEST_TARGET` conforming to [robust-testing](file:///var/home/nrd/git/github.com/nrdxp/predicate/skills/robust-testing/SKILL.md) instructions:
   - **Specification Mapping:** If a specification or model exists, the tests MUST directly verify its constraints and state transitions to ensure meaningful surface coverage.
   - **Verification Method Selection:** Select the verification method based on domain complexity:
     - Use **Property-Based Testing (PBT)** if the domain has non-trivial algebraic properties (e.g., round-trip, commutativity, idempotency) and target language support is mature.
     - Use **Fuzz Testing** to validate security and serialization boundaries for untrusted inputs.
     - Use **Metamorphic Testing** if the expected output is complex/expensive to calculate or lacks a simple oracle.
     - Use **Integration/E2E Testing** for multi-module boundaries, asserting global liveness/safety while isolating external APIs via deterministic mocks.
- **Baseline Check**: Run `VALIDATOR` to obtain the baseline error differential $\Delta E_0$. The baseline check MUST verify test failure ($\Delta E_0 \neq 0$) to confirm the test is non-trivial and does not pass on empty/unimplemented code.
- **Generation**: Implement code edits at `IMPL_TARGET` to satisfy `IMPL_DELTA`.
- **Deterministic Evaluation**: Execute `VALIDATOR`.
   - If tests/compilation pass ($V(\mathbf{S}_k) = 0$), proceed to the Refinement Check.
   - If tests/compilation fail ($V(\mathbf{S}_k) \neq 0$), apply a corrective edit $\Delta \mathbf{S}_{k+1}$ designed to minimize the error feedback vector $\Delta E_k$. Repeat up to a cap of 3-5 iterations. If no convergence occurs, transition to `CLARIFY` and halt.
 
### 2. Iterative Refinement Loop
Before concluding work at any commit boundary:
- Audit the generated diff against code simplicity (Hickey complecting check), volatility alignment (Lowy temporal check), test completeness, and style guidelines.
- **One-Shot Skeptical Audit**: If a plan step converges in exactly 1 iteration (`LOOPS: 1`), you must perform an explicit adversarial audit of the diff. Validate that the baseline failure check was genuine, analyze whether any hidden assumptions were left unverified, and run spatial/temporal checks to ensure no structural complexity was introduced. Document this audit in the `REVIEW` block under `SKEPTICAL_AUDIT`.
- Update the **Dynamic Sketchpad** rubric ledger (including goals/evaluators), constraint ledger, unknowns ledger, and standards checklists in `.sketches/[topic].md` to track compliance states in real-time. Log any dynamic shifts or refinements to the rubric goals for human reporting.
- If the quality score is less than 1.0 or any standard/constraint is violated, formulate a corrective refactor, apply it, and re-run verification.
 
### 3. Commit Gates
At each commit boundary (or phase completion):
- **Commit Hygiene Invariant:** Ensure the conventional commit message is validated and satisfies the constant `commit-hygiene` constraint before executing any commit in either repository.
- If `CONTROL_MODE: AUTOMATIC` (and credentials/command permissions are active):
  1. Record the updated Dynamic Sketchpad ledger (rubric, constraints, unknowns, standards, commit ID) in `.sketches/[topic].md`, and commit it within the `.sketches/` subrepo.
  2. Output the `REVIEW` block, `JUSTIFICATION` block, and conventional commit message.
  3. Execute `git add [modified files]` and `git commit -m "[message]"` directly.
  4. Automatically proceed to the remaining PLAN steps without halting.
- If `CONTROL_MODE: MANUAL` (or not specified):
  1. Output in this order, then **HALT**:
     - REVIEW block (structured output of self-review findings: SCORE, ITERATIONS, and FINDINGS per the REVIEW Block Format)
     - Sketch update instructions (re-stating the Dynamic Sketchpad ledger updates, compiling any rubric adjustments or goal additions)
     - JUSTIFICATION block
     - Conventional commit message conforming to [commit-hygiene](file:///var/home/nrd/git/github.com/nrdxp/predicate/skills/commit-hygiene/SKILL.md)
     - REMAINING STEPS
  2. **Wait for human confirmation** before proceeding.
 
### 4. REVIEW Block Format
The `REVIEW` block must be output as a structured YAML block containing:
```yaml
REVIEW:
  SCORE: 1.0                              # Qualitative self-audit score [0.0 - 1.0]
  ITERATIONS:
    - STEP_ID: 1                          # Links to the trajectory plan step ID
      BASELINE_FAIL: "Verified diagnostic baseline error / test fail output"
      LOOPS: 3                            # Exact number of verification loops executed (1-5)
      CORRECTIONS:
        - LOOP: 1
          ERROR: "Error output details"
          CORRECTION: "Applied changes to fix"
      VERIFICATION: "Pass evidence / test execution summary"
      SKEPTICAL_AUDIT: "Adversarial audit detail (Mandatory if LOOPS: 1)"
  FINDINGS:
    - ID: F1
      SEVERITY: [LOW | MEDIUM | HIGH | CRITICAL]
      ACTION: "Simplicity / volatility alignment correction applied"
      DETAIL: "Trace audit context"
```

---
 
## Prime Directives
 
1. **STATE_OVER_SCRIPT:** Define the desired state declaratively in YAML. The PLAN must specify atomic TDD steps and verification constraints.
2. **AMBIGUITY_GATE:** If context is missing, conflicting, or weak (UNCERTAINTY > 0.0), token generation for implementation is forbidden. Transition to CLARIFY, populate OBSTACLES, and halt.
3. **VERIFICATION_FIRST:** Every PLAN step requires a testable assertion. A task is incomplete without verification.
4. **TOKEN_MINIMALISM:** Eradicate conversational filler. Output only the CORE-YAML grammar during planning.
5. **HANDSHAKE_PROTOCOL:** Transition to EXECUTE is forbidden without explicit human approval (unless continuing on a fully automated `CONTROL_MODE: AUTOMATIC` run).
6. **PREDICATE_AWARENESS:** Maintain conformance with active workspace skills.
7. **SCHEMA_RIGIDITY:** Permitted fields in the CORE-YAML grammar are strictly constrained to: STATUS, CONTROL_MODE, UNCERTAINTY, STABILITY, REASONING, CTX, OBSTACLES, PLAN.
8. **DEBT_TRANSPARENCY:** Suboptimal compromises must be documented in `JUSTIFICATION.DEBT` and recorded in the plan's `## Technical Debt` section.
9. **DEVIATION_RECORDING:** Deviations from the plan must be recorded in the plan's `## Deviation Log` section at commit boundaries.
 
### Protocol Violations (FORBIDDEN)
 
| Violation | Why It's Wrong |
| :--- | :--- |
| Adding fields not listed in SCHEMA_RIGIDITY | Violates grammar constraints. |
| Skipping commit message | Breaks repository history standards. |
| Executing `git commit` without authorization | User commits manually unless `CONTROL_MODE: AUTOMATIC` is active and authorized. |
| Proceeding past commit boundary without human confirmation | Each boundary is a halt gate (unless `CONTROL_MODE: AUTOMATIC`). |
| Continuing after verification failure | Must run the Closed-Loop Verification Loop to fix, or halt if it fails to converge. |
| Proceeding past COMMIT without updating sketch | Destroys decision logs. |
| Implementing code changes without writing the test invariant first | Violates TDD constraints. |
 
---
 
## State Transitions & Definitions
 
```
ABSORB ──→ CLARIFY (if OBSTACLES exist)
       └─→ PLAN    (if UNCERTAINTY = 0.0)
 
CLARIFY ──→ PLAN   (once OBSTACLES resolved)
 
PLAN ──→ EXECUTE  (on "APPROVED")
     └─→ CLARIFY  (if new ambiguity discovered)
 
EXECUTE ──→ CLARIFY (if verification fails to converge)
         └─→ ABORT   (if target state space is unreachable)
```
 
**ABSORB:** Ingest input, map target attractor basin.
 
**CLARIFY:** Halt generation; emit obstacles to resolve uncertainty.
 
**PLAN:** Construct the discrete state trajectory mapping transitions to TDD targets and invariants.
 
**EXECUTE:** Formulate test invariants, check baseline, run candidate code generation, run verification, minimize the error differential, and apply commit gates.
 
**ABORT:** Halt and exit the trajectory walk when the target state space is proven unreachable.
 
---
 
## Lexicon Translation Matrix

> See the canonical Invariant Translation Mapping in [rules.md](file:///var/home/nrd/git/github.com/nrdxp/predicate/rules.md) §1 for the full mapping between psychological heuristics and control-theoretic operations.