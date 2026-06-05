---
name: refine
description: |
  SOP for the automated refinement loop (/refine) workflow.
  Trigger when:
  - Exhaustively auditing and optimizing pre-existing codebase artifacts.
  - Applying iterative contraction mapping to reduce code entropy.
  - Prompt contains: /refine, refinement loop, contraction mapping, fixed-point sweep.
---

# REFINE Protocol v1.0: Contraction Mapping & Fixed-Point Convergence

**Absorb → Audit → Iterate → Sweep → Report**

This workflow defines the `/refine` execution loop. The objective is to guide sequence token generation through a series of discrete state transitions (Absorb, Audit, Iterate, Sweep, Report) to systematically reduce the entropy of pre-existing artifacts. The process is modeled as an iterative contraction mapping that halts only when a stable fixed point is verified.

---

## Philosophy & Mathematical Model

Refining an existing artifact is modeled as finding the unique fixed point $\mathbf{S}^*$ of a state-space contraction mapping. Let $\mathcal{X}$ be the space of artifact configurations, and let $d: \mathcal{X} \times \mathcal{X} \rightarrow \mathbb{R}_{\ge 0}$ be a metric proportional to the residual entropy and count of latent/active flaws. The refinement operator $R: \mathcal{X} \rightarrow \mathcal{X}$ is a contraction if:

$$d(R(\mathbf{A}), R(\mathbf{B})) \le q \cdot d(\mathbf{A}, \mathbf{B})$$

for all $\mathbf{A}, \mathbf{B} \in \mathcal{X}$ and some contraction factor $0 \le q < 1$. By the Banach Fixed-Point Theorem, repeated application of $R$ converges to the unique fixed point:

$$\mathbf{S}^* = \lim_{k \rightarrow \infty} R^k(\mathbf{S}_0)$$

To ensure sequence generations converge to $\mathbf{S}^*$ rather than terminating in local sub-optimal minima, the workflow enforces three control-theoretic bounds:

1. **Minimum Execution Loops ($N_{min}$):** The loop MUST execute at least $N_{min}$ (default 3) iterations, even if no issues are initially visible.
2. **Consecutive Clean Sweeps ($M_{sweep}$):** Once the active refinement ledger is empty, the agent must perform $M_{sweep}$ (default 3) consecutive adversarial scans (sweeps) across the entire modified state space. If any sweep detects a regression, code smell, or optimization gap, a new target is logged, the sweep counter resets to zero, and the system returns to the `ITERATE` state.
3. **Divergence Boundary ($K_{max}$):** To prevent infinite limit cycles or chaotic oscillations (where edits iteratively trigger alternating side-effects), we define a loop limit $K_{max}$ (default 8). If $k > K_{max}$, the controller halts and triggers a stability failure.

---

## Scope

> [!IMPORTANT]
> `/refine` is for **optimizing and polishing pre-existing artifacts**. It is NOT for implementing new features (that's `/core`) or drafting high-level architecture plans (that's `/plan`). If the sequence begins adding new functional scopes or diverging from the initial target artifact, the walk must halt and return control to the human.

---

## Grammar

```yaml
# 1. METADATA
STATUS: [ABSORB | CLARIFY | AUDIT | ITERATE | SWEEP | REPORT | HALT]
UNCERTAINTY: [0.0-1.0]       # Residual uncertainty. Must be 0.0 to proceed to AUDIT.

# 2. CONTEXT
CTX:
  TARGET_ARTIFACTS:
    - "path/to/target/file"
  GOAL: "Verbatim objective statement"
  CONSTRAINTS:
    N_MIN: 3                 # Minimum loop execution count
    M_SWEEP: 3               # Required consecutive zero-finding sweeps
    K_MAX: 8                 # Maximum loops before halting (divergence boundary)

# 3. DYNAMIC REFINEMENT LEDGER
# Track all optimization targets identified during AUDIT or SWEEP phases.
# All items must be RESOLVED before entering the final SWEEP validation gates.
REF_LEDGER:
  - ID: R1
    AXIS: [CORRECTNESS | API_SUFFICIENCY | QUALITY | EDGE_CASES]
    TARGET: "symbol_or_line_or_file"
    STATEMENT: "Description of the target improvement"
    STATUS: [PENDING | IN_PROGRESS | RESOLVED]
    EVIDENCE: "Verification results / test run outputs"

# 4. ITERATIVE TRACE
# Live execution metrics updated at each loop boundary
TRACE:
  CURRENT_LOOP: 0              # Current iteration index (k)
  CONSECUTIVE_CLEAN_SWEEPS: 0  # Number of consecutive clean sweeps completed
  LOOPS:
    - LOOP: 1
      TARGETS_ADDRESSED:
        - R1
      VERIFICATION: "Compiler/linter/test outputs"
      COMMITS:
        - "git-commit-hash: conventional commit message"
```

---

## State Transitions & Definitions

```
ABSORB ──→ CLARIFY   (if UNCERTAINTY > 0.0)
       └─→ AUDIT     (if UNCERTAINTY = 0.0)

CLARIFY ─→ AUDIT     (once uncertainty resolved)
 
AUDIT  ──→ ITERATE   (if ledger has PENDING items)
       └─→ SWEEP     (if ledger is empty)
 
ITERATE ─→ SWEEP     (once all ledger items are RESOLVED and CURRENT_LOOP <= K_MAX)
         └─→ HALT     (if CURRENT_LOOP > K_MAX or loop oscillation is detected)
 
SWEEP  ──→ ITERATE   (if a sweep discovers new issues, resetting sweeps to 0)
       └─→ REPORT    (once CONSECUTIVE_CLEAN_SWEEPS = M_SWEEP and CURRENT_LOOP >= N_MIN)
```

### 1. ABSORB
Ingest the target artifact, the optimization goals, and any relevant specs or test suites. Setup the tracking ledger in the active sketch file. If there is ambiguity in the goal or scope, set `UNCERTAINTY` > 0.0 and transition to `CLARIFY`.

### 2. CLARIFY
Halt sequence generation. Surface obstacles or questions regarding the target artifacts or goals. Wait for human validation before resolving and transitioning to `AUDIT`.

### 3. AUDIT
Exhaustively analyze the artifact across four dimensions to identify how to achieve its **minimal representation** (optimal articulation of the problem space without superfluous complexity):
- **Correctness & Verification:** Test surface coverage, boundary constraints, and potential regression pathways.
- **API Sufficiency & Elegance:** Complection (Hickey check), coupling, and module boundaries.
- **Code Quality & Simplicity:** Readability, formatting, and structural cleanliness.
- **Edge Cases & Gaps:** Error handling limits, security boundaries, and performance bottlenecks.

Populate the `REF_LEDGER` with all discovered targets. If no targets are found, transition to `SWEEP`.

### 4. ITERATE
For each ledger item:
1. Apply the local closed-loop verification loop:
   - **For code artifacts:** Apply TDD validation (write/update tests, verify baseline failure, implement changes, verify success).
   - **For non-code artifacts (e.g. documentation, specifications):** Apply rigorous linting, link checking, style alignment audits (e.g. [documentation](../documentation/SKILL.md)), and structural completeness checks. Verify baseline deficiency before correction.
2. Commit the change using conventional commits, conforming to [commit-hygiene](../commit-hygiene/SKILL.md).
3. Update the ledger item status to `RESOLVED` with evidence.
4. Update the sketch ledger and commit within the `.sketches/` subrepo.

### 5. SWEEP
Once the ledger is empty:
1. Conduct an adversarial sweep across the entire modified space. The sweep should act as a high-sensitivity sensor, asking:
   - *Did any modification introduce complected logic or tight coupling (Hickey check)?*
   - *Did any change break architectural boundaries or axis of change isolation (Lowy check)?*
   - *Are there edge cases, bad inputs, or security vulnerabilities introduced or unhandled?*
   - *Does the documentation or type signature deviate from the implementation?*
2. If any new issue, regression, or code smell is found:
   - Add a new item to `REF_LEDGER` with status `PENDING`.
   - Reset `CONSECUTIVE_CLEAN_SWEEPS` to 0.
   - Transition to `ITERATE`.
3. If the sweep is clean (zero new findings):
   - Increment `CONSECUTIVE_CLEAN_SWEEPS` by 1.
   - If `CONSECUTIVE_CLEAN_SWEEPS` < `M_SWEEP` or `CURRENT_LOOP` < `N_MIN`, run another sweep loop.
   - If `CONSECUTIVE_CLEAN_SWEEPS` >= `M_SWEEP` and `CURRENT_LOOP` >= `N_MIN`, transition to `REPORT`.

### 6. REPORT
Compile and output the final refinement report using the template at `templates/REFINE.md`.

---

## Prime Directives

1. **FIXED_POINT_RIGOR:** Never declare completion without executing the minimum $N_{min}$ loops and satisfying the $M_{sweep}$ consecutive clean sweeps constraint.
2. **ATOMIC_REFINEMENTS:** Every refinement commit must be logically atomic. Do not bundle unrelated refactorings or style updates into a single transaction.
3. **SKEPTICAL_SWEEPS:** Sweeps must be adversarial. Actively attempt to find flaws, side-effects of edits, or overlooked gaps in the modified codebase.
4. **SKETCH_SYNCHRONIZATION:** The active sketchpad ledger in `.sketches/` must be updated and committed in the subrepo at every loop boundary.
5. **COMMIT_HYGIENE:** All commits must strictly conform to [commit-hygiene](../commit-hygiene/SKILL.md).
6. **DIVERGENCE_HALT:** If the execution loop count exceeds $K_{max}$ or oscillations/cycles are detected, transition to `HALT` immediately and do not attempt to auto-resolve.
