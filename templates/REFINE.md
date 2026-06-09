# REFINEMENT REPORT: [Topic]

<!--
  REFINEMENT REPORT documents compile the outcomes of a /refine execution.
  They present the trace of iterative modifications, verification loops,
  and multi-pass fixed-point sweeps to demonstrate convergence.

  See: [skills/refine/SKILL.md](../skills/refine/SKILL.md) for the full protocol specification.
-->

## Goal

<!-- Verbatim objective and scope of the target artifacts being refined -->

- **Target Artifacts:**
  - `[path/to/artifact/1]`
  - `[path/to/artifact/2]`
- **Goal Statement:** [Describe the target outcome of this refinement run]

## Execution Summary

- **Execution Mode:** [INTERACTIVE | AUTONOMOUS]
- **Autonomous Assumptions:** [List assumptions formulated under autonomous mode, or N/A]
- **Meta-Auditor Approval Mode:** [INTERACTIVE | PROGRAMMATIC_AUTONOMOUS]
- **Total Refinement Loops ($k$):** [Count]
- **Consecutive Clean Sweeps ($M$):** [Count]
- **Total Rollback Count:** [Count]
- **Sibling Skills Consulted:** [e.g., robust-testing, engineering, prior-art]
- **Initial Baseline State:** [Describe initial flaws, gaps, or complexity metrics before refinement]
- **Final Convergence State:** [Describe final optimized state, verified bounds, and evidence]

---

## Refinement Ledger

<!--
  List all optimization targets identified during AUDIT or SWEEP loops,
  along with their resolution status and verification evidence.

  Valid Axis values: CORRECTNESS, API_SUFFICIENCY, COMPLIANCE, EDGE_CASES
  Grounded Ledger Invariant: Only enter items that are deterministically grounded in linter/compiler outputs, test failures, or documented spec contract violations.
-->

| ID | Axis | Target | Improvement Description | Status | Evidence |
| :--- | :--- | :--- | :--- | :--- | :--- |
| R1 | [Axis] | [Target] | [Description] | RESOLVED | [Test pass link/log] |
| ... | ... | ... | ... | ... | ... |

---

## Iteration History

<!-- Detailed log of changes made per loop, matching commit hygiene -->

### Loop [N]

- **Targets Addressed:** [e.g. R1, R2]
- **Applied Modifications:**
  - [Describe edits made to code/docs]
- **Trace Metrics:**
  - **Proxy Error Metric ($d_p$):** [Count]
  - **Convergence Rate ($\rho$):** [Ratio]
  - **Tracked Workspace Hashes:**
    - `[path/to/file]`: `[sha256]`
- **Verification Trace:**
  - [Validator run outputs / test status]
- **Commits:**
  - `[commit-hash]` [Conventional commit message]

---

## Verification Sweep Log

<!-- Log of the Multi-Boundary Subagent Sweeps (MBSS) performed after all ledger items were resolved -->

### Sweep [N]

- **Meta-Auditor ID:** `[conv-uuid]`
- **Meta-Auditor Validation Summary:** [Provide the Meta-Auditor's evaluation of the angles, any gaps identified, and the finalized set of rubrics]
- **Sweep Result:** [CLEAN | FINDINGS_FOUND]
- **Adversarial Subagents Executed:**
  - **Subagent A1 (`[conv-uuid]`):** [Name/Persona]
    - **Rubric:** [What was checked]
    - **Result:** [PASS | FAIL (Findings details)]
  - **Subagent A2 (`[conv-uuid]`):** [Name/Persona]
    - **Rubric:** [What was checked]
    - **Result:** [PASS | FAIL (Findings details)]

---

## Final Compliance Audit

- **Simplicity Audit (Hickey check):** [Explain why concerns are uncomplected and state is cleanly managed]
- **Volatility Audit (Lowy check):** [Explain why axes of change are cleanly isolated]
- **Test Invariants Compliance:** [Verify all test invariants remain fully satisfied]
- **Socratic Purpose Checklist Trace:** [Detail how the implementation moves past a superficial prop to a production-grade art, and how it represents the minimal representation of the goal]
- **Sieving & Cutting Analysis:** [Document the sieving/cutting process: details on whether any components, parameters, or configurations were pruned or simplified, or the justification for why every remaining component is strictly necessary to achieve the goal]

---

## Post-Mortem Process Audit

- **Adversarial Auditor ID:** `[conv-uuid]`
- **Audit Findings:** [Critically analyze the refinement run. Where did the refiner overcorrect, loop inefficiently, deviate from scope, or miss structural simplifications?]
- **Retrospective Recommendations:** [What could have been done differently or better? How can the protocol or execution parameters be optimized for future runs?]

