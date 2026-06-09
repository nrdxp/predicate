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

### Prefix-Induced Attractor Basin Bias
Autoregressive Large Language Models do not generate tokens in a vacuum; they traverse a sequence probability landscape where each token step is conditioned on the historical prefix $\mathbf{S}_t$. When the same agent that modified the code also reviews it, the prefix $\mathbf{S}_t$ contains the refiner's internal steps, design rationale, and implicit assumptions. This warps the landscape to construct a deep **attractor basin** around the refiner's localized choices, mathematically biasing the walk to reinforce its own decisions.

To break this self-congratulatory lock-in and achieve a non-delusional fixed point $\mathbf{S}^*$, validation must execute under **Multi-Boundary Subagent Sweeps (MBSS)**. We project the artifact's state space onto orthogonal axes of critique using independent subagents primed with distinct Initial Boundary Conditions (IBCs) that are completely blind to the refiner's internal trajectory history.

To ensure sequence generations converge to $\mathbf{S}^*$ rather than terminating in local sub-optimal minima, the workflow enforces three control-theoretic bounds that scale dynamically based on the complexity of the task (assessed during `ABSORB`):

1. **Minimum Execution Loops ($N_{min}$):** The loop MUST execute at least $N_{min}$ iterations, even if no issues are initially visible. This scales adaptively:
   - *Simple (minor edits/docs):* $N_{min} = 3$
   - *Medium (single-module refactors, testing sweeps):* $N_{min} = 4$
   - *Complex (protocol updates, state-machine changes):* $N_{min} \ge 4$
2. **Consecutive Clean Sweeps ($M_{sweep}$):** Once the active refinement ledger is empty, the agent must perform $M_{sweep}$ consecutive adversarial sweeps. This scales adaptively:
   - *Simple/Medium tasks:* $M_{sweep} = 3$
   - *Complex/Critical tasks:* $M_{sweep} \ge 4$
3. **Divergence Boundary ($K_{max}$):** To prevent infinite limit cycles or chaotic oscillations (where edits iteratively trigger alternating side-effects), we define a loop limit $K_{max}$:
   - *Simple tasks:* $K_{max} = 8$
   - *Medium tasks:* $K_{max} = 10$
   - *Complex tasks:* $K_{max} \ge 12$

Only when $M_{sweep}$ consecutive sweeps find zero new issues can the system declare convergence ($R(\mathbf{S}^*) = \mathbf{S}^*$) and proceed to the `REPORT` phase.

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
    N_MIN: 4                 # Adaptive loop limit scaled to task complexity
    M_SWEEP: 4               # Adaptive sweep limit scaled to task complexity
    K_MAX: 12                # Adaptive divergence boundary
    COGNIZANCE:              # Sibling skills loaded and consulted during audit
      - robust-testing
      - engineering
      - prior-art

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

# 4. ADVERSARIAL SWEEP SYSTEM (MBSS)
# Track the dynamically identified adversarial review angles and subagent sessions.
MBSS_PLAN:
  META_AUDITOR_STATUS: PENDING # APPROVED once meta-auditor validates the angles list
  ANGLES:
    - ID: A1
      NAME: "e.g., security-sandbox"
      RUBRIC: "Search for specific resource leak or sandbox escape"
      SUBAGENT_ID: "conv-uuid"
      STATUS: PENDING          # [PENDING | PASS | FAIL]

# 5. ITERATIVE TRACE
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

**Adaptive Parameter Bounds Initialization:**
Evaluate the complexity of the target artifact and goal. Scale the limits dynamically:
- *Simple (local edits, docs):* Set $N_{min}=3$, $M_{sweep}=3$, $K_{max}=8$.
- *Medium (single-module refactoring, test suite updates):* Set $N_{min}=4$, $M_{sweep}=3$, $K_{max}=10$.
- *Complex (core logic changes, protocol designs, multi-file refinements):* Set $N_{min} \ge 4$, $M_{sweep} \ge 4$, $K_{max} \ge 12$.

Log these parameters and their complexity rationale in the sketch.

### 2. CLARIFY
Halt sequence generation. Surface obstacles or questions regarding the target artifacts or goals. Wait for human validation before resolving and transitioning to `AUDIT`.

### 3. AUDIT
Exhaustively analyze the artifact across four dimensions to identify how to achieve its **minimal representation** (optimal articulation of the problem space without superfluous complexity). 

**Sibling Skills Consultation:**
You are required to actively consult the workspace's sibling skills to think more broadly:
- Mapped tests MUST be checked against the guidelines in [robust-testing](../robust-testing/SKILL.md) (verifying that PBT, fuzzing, and boundary sweeps are fully utilized rather than simple positive test cases).
- Code safety and type boundaries MUST conform to the procedural directives in [engineering](../engineering/SKILL.md).
- Architectural designs and abstractions MUST be compared against patterns in [prior-art](../prior-art/SKILL.md) to ground decisions in proven implementations.
- API surface designs must be evaluated against complection and decoupling rules in [api-audit](../api-audit/SKILL.md), [hickey](../hickey/SKILL.md), and [lowy](../lowy/SKILL.md).

**Socratic Purpose Checklist:**
Evaluate the implementation by asking:
- *Is this solution a toy, a superficial prop, or genuine production-grade art?*
- *What is the higher-level goal, and what is truly necessary to achieve it to the optimal degree?*
- *Are we ignoring or glossing over hidden complexities to finish quickly?*

**Sieving & Cutting Check:**
Look for opportunities to simplify the system structure. Ask:
- *Is there any feature, dependency, parameter, configuration option, or documentation section that is superfluous?*
- *Would cutting, merging, or deleting components improve the overall clarity, type-safety, or maintainability without violating structural constraints?*

Populate the `REF_LEDGER` with all discovered targets (including items to be simplified or pruned). If no targets are found, transition to `SWEEP`.

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
1. **Dynamic Angle Identification:** The refiner analyzes the scope of modifications and lists the relevant **Adversarial Audit Angles** (dimensions of the state-space) that must be audited. These must span every conceivable risk category for the modification (e.g., security, edge cases, UX, concurrency, performance, schema safety).
2. **Spawn Meta-Auditor:** Spawn an independent subagent with a clean context, passing the goal, constraints, final code/diff, and the proposed audit angles.
   - **Role:** Meta-Auditor
   - **Goal:** Audit the proposed review angles for completeness. Check for structural blind spots (e.g., "You touched the DB but have no schema-migration angle"). Refine and sharpen the subagent prompts to ensure they are highly critical and target real vulnerability boundaries.
   - **Constraint:** The sweep cannot proceed until the Meta-Auditor approves the angles list and sets `META_AUDITOR_STATUS: APPROVED`.
3. **Execute Isolated Subagent Audits:** For each approved angle, the refiner spawns an independent subagent in an isolated context (blind to the refiner's internal trajectory and other subagents):
   - **IBC Setup:** Initialize the subagent with the specific custom prompt/persona approved by the Meta-Auditor.
   - **Task:** Critically review the modified files against its specific rubric and output either `STATUS: PASS` or a structured list of findings.
4. **Evaluate Findings:**
   - If *any* subagent reports findings:
     - Merge the findings into `REF_LEDGER` as `PENDING` items.
     - Reset `CONSECUTIVE_CLEAN_SWEEPS` to 0.
     - Reset `META_AUDITOR_STATUS` to `PENDING`.
     - Transition to `ITERATE`.
   - If *all* subagents report `PASS`:
     - Increment `CONSECUTIVE_CLEAN_SWEEPS` by 1.
     - If `CONSECUTIVE_CLEAN_SWEEPS` < `M_SWEEP` or `CURRENT_LOOP` < `N_MIN`, run another sweep loop (which requires generating a fresh meta-audit and spawning fresh subagents to ensure no state pollution).
     - If `CONSECUTIVE_CLEAN_SWEEPS` >= `M_SWEEP` and `CURRENT_LOOP` >= `N_MIN`, transition to `REPORT`.

### 6. REPORT
Compile and output the final refinement report using the template at `templates/REFINE.md`.

---

## Prime Directives

1. **FIXED_POINT_RIGOR:** Never declare completion without executing the minimum $N_{min}$ loops and satisfying the $M_{sweep}$ consecutive clean sweeps constraint.
2. **ATOMIC_REFINEMENTS:** Every refinement commit must be logically atomic. Do not bundle unrelated refactorings or style updates into a single transaction.
3. **ORTHOGONAL_SWEEPS:** Every sweep MUST execute Multi-Boundary Subagent Sweeps (MBSS). Spawning specialized, isolated review subagents approved by an independent Meta-Auditor is mandatory. Self-auditing by the refiner alone is forbidden.
4. **SKETCH_SYNCHRONIZATION:** The active sketchpad ledger in `.sketches/` must be updated and committed in the subrepo at every loop boundary.
5. **COMMIT_HYGIENE:** All commits must strictly conform to [commit-hygiene](../commit-hygiene/SKILL.md).
6. **DIVERGENCE_HALT:** If the execution loop count exceeds $K_{max}$ or oscillations/cycles are detected, transition to `HALT` immediately and do not attempt to auto-resolve.
