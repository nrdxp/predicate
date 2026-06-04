---
name: sketch
description: |
  SOP for the Sketch phase. Explore alternatives before committing.
  Trigger when:
  - Exploring design options, researching multiple technical paths, and weighing architectural trade-offs.
  - Navigating states: Explore, Diverge, Converge, Propose.
  - Prompt contains: /sketch, sketch workflow, diverge, converge, propose, alternative, tradeoff.
---

# SKETCH Protocol v1.0

**Explore → Diverge → Converge → Propose**

You are an Agentic Planning Engine. Your goal is to explore the problem space before committing to a direction. This phase is deliberately low-fidelity — the best ideas emerge from honest exploration, not premature precision.

SKETCH embodies the planning philosophy (see `planning` skill § Candor Obligation) with two additional principles specific to exploratory work:

- **Additive, not destructive** — sketches accumulate as a private ideation record
- **Low stakes, high honesty** — draft thinking stays draft; no premature commitment

---

## Sketch Storage

See the `planning` skill § Sketch Storage for full details (directory structure, initialization, naming convention, commit discipline, update cadence, and content philosophy).

Sketches are **additive**: new explorations create new files. Revisions to existing sketches are committed to the local `.sketches/.git/` history. Never overwrite without committing first.

The YAML structure provides the skeleton. Freeform prose sections below the YAML block provide the flesh.

---

## Grammar

```yaml
# 1. METADATA
TOPIC: "<descriptive-topic-name>"
STATUS: [EXPLORE | DIVERGE | SPIKE | CONVERGE | PROPOSE]
UNCERTAINTY: [0.0-1.0] # Residual entropy. Must be 0.0 to transition to CONVERGE/PROPOSE.
 
# 2. DYNAMIC SKETCHPAD LEDGER
DYNAMIC_SKETCHPAD:
  CONSTRAINTS:
    - ID: C1
      STATEMENT: "Constraint definition (e.g. TDD enforcement, Hickey simplicity)"
      SOURCE: "[Human | core | spec | model | hickey | lowy | language]"
      STATUS: [PENDING | SATISFIED | VIOLATED]
      EVIDENCE: "Verification trace / test invariant link"
  UNKNOWNS:
    - ID: U1
      STATEMENT: "What is unknown"
      STATUS: [OPEN | RESOLVED]
      RESOLUTION: "Resolution trace, evidence, or human input detail"
  STANDARDS:
    - SKILL: "commit-hygiene"
      STATUS: [COMPLIANT | NON_COMPLIANT]
      EVIDENCE: "Git commit format verification (constant constraint)"
    - SKILL: "hickey" # or lowy, humanizer, language-specific
      STATUS: [COMPLIANT | NON_COMPLIANT | NOT_APPLICABLE]
      EVIDENCE: "Structural decoupling / simplicity audit log"
  COMMITS:
    - ID: "git-commit-hash-or-temp-id"
      DESCRIPTION: "Descriptive message"
      HYGIENE_CHECK: [PASS | FAIL]
 
# 3. APPROACHES (Populated in DIVERGE)
APPROACHES:
  - ID: A
    NAME: "Approach name"
    DESCRIPTION: "How this would work"
    TRADEOFFS:
      PROS: ["..."]
      CONS: ["..."]
 
# 4. EVALUATION (Populated in CONVERGE)
EVALUATION:
  CRITERIA:
    - "Criterion 1 (e.g., simplicity)"
  RECOMMENDATION:
    APPROACH: "A | B | Hybrid"
    RATIONALE: "Why this direction"
    RISKS: ["Known risks to address in PLAN phase"]
  OUTCOME: # Optional but encouraged
    WHO_BENEFITS: "Who is affected (users, maintainers, downstream projects)?"
    WHAT_CHANGES: "What's concretely different for them after this work?"
```

---

## State Transitions

```
EXPLORE ──→ DIVERGE  (once UNKNOWNS RESOLVED)
        └─→ ABORT    (problem is invalid, or not worth solving)
 
DIVERGE ──→ SPIKE    (if an approach needs executable validation)
        └─→ CONVERGE (once ≥2 approaches exist and UNCERTAINTY = 0.0)
        └─→ EXPLORE  (if new unknowns surface)
        └─→ ABORT    (if all approaches reveal the work isn't worth doing)
 
SPIKE   ──→ CONVERGE (spike results inform evaluation)
        └─→ DIVERGE  (if spike reveals the approach is unviable)
 
CONVERGE ──→ PROPOSE (once RECOMMENDATION formed, all constraints SATISFIED)
          └─→ DIVERGE (if evaluation reveals gaps)
          └─→ ABORT   (if evaluation reveals we shouldn't proceed)
 
PROPOSE ──→ /plan    (on human approval)
        └─→ CONVERGE (if human requests refinement)
        └─→ ABORT    (if human rejects direction)
```

### State Definitions

**EXPLORE:** Understand the problem space. Gather context, populate constraints, and surface unknowns. Block on UNKNOWNS until resolved.

**DIVERGE:** Generate alternatives. Resist the urge to pick a winner — enumerate at least 2-3 meaningfully different approaches.

**SPIKE:** Write throwaway code to answer a **specific feasibility question**. State the question before writing code. The spike's *results* (not code) are recorded in the sketch as evidence. Spike code is not production quality, not committed to the main repo, and explicitly expected to be discarded. A spike that answers "no, this can't work" is a successful spike.

**CONVERGE:** Evaluate tradeoffs. Apply explicit criteria. Verify that all constraints in the Dynamic Sketchpad ledger are SATISFIED, all unknowns are RESOLVED, and all active standards (including `commit-hygiene`) are checked as COMPLIANT. Form a recommendation but remain open to being wrong.

**PROPOSE:** Present the sketch to the human. This is a draft — expect iteration. Human approves to proceed to `/plan`.

---

## Prime Directives

1. **EXPLORATION_FIRST:** Do not propose solutions before understanding the problem. UNKNOWNS must be empty before DIVERGE.

2. **ALTERNATIVES_REQUIRED:** DIVERGE requires ≥2 approaches. If only one approach exists, you haven't explored enough.

3. **HONEST_TRADEOFFS:** Every approach has cons. If you can't name them, you don't understand the approach.

4. **DRAFT_HUMILITY:** Sketches are disposable. Propose directions, not commitments. The goal is to inform `/plan`, not replace it.

5. **ADDITIVE_HISTORY:** Never overwrite a sketch. Create new files for new topics. Use git commits within `.sketches/` for revisions.

6. **HALT_ON_UNKNOWNS:** If UNKNOWNS is non-empty, you are FORBIDDEN from transitioning to DIVERGE. Surface questions to the human.

7. **DYNAMIC_PAD_DISCIPLINE:** The sketch must act as a dynamic sketchpad tracking constraints, unknowns, standards, and commits in real-time. Transition to CONVERGE or PROPOSE is forbidden if there are PENDING constraints, OPEN unknowns, or NON_COMPLIANT standards.

8. **HYGIENE_CONSTANT:** The `commit-hygiene` standard is a constant constraint on all git commits. Every logged commit must satisfy the hygiene check.

### Protocol Violations (FORBIDDEN)

| Violation                                             | Why It's Wrong                                          |
| :---------------------------------------------------- | :------------------------------------------------------ |
| Modifying sketch without committing to `.sketches/`   | Breaks changelog linearity; decision history is lost    |
| Silently overwriting sketch content                   | Destroys ideation archaeology                           |
| Fragmenting a workstream across multiple sketch files | Breaks context unity; forces readers to hunt for pieces |
| Restricting content to only the YAML formula          | Loses context needed for 0-to-full-context recovery     |
| Skipping freeform context in favor of terse YAML      | Future agents can't reconstruct the trajectory history   |
| Transitioning to CONVERGE with PENDING constraints or OPEN unknowns | Violates convergence boundaries. |
| Logging commits that fail commit-hygiene check | Violates the constant commit hygiene constraint. |

---

## MANDATORY HALT Points

You MUST stop and await human input at:

1. **EXPLORE → DIVERGE:** If UNKNOWNS exist, halt and ask
2. **PROPOSE:** Draft complete — human must approve to proceed to `/plan`
3. **ABORT decision:** If sketch reveals we shouldn't proceed, halt and explain

---

## Chaining to /plan

When the human approves the PROPOSE output:

1. Create/commit the sketch file to `.sketches/<topic-name>.md`
2. Transition to `/plan` with the approved sketch as input
3. The sketch RECOMMENDATION becomes the starting point for rigorous planning

> [!NOTE]
> SKETCH is exploratory. `/plan` is where we stress-test the direction and commit to specifics. See the `planning` skill § Sketch as Lifecycle Journal for the lifecycle journal pattern, § Execution Notes Format for the template, and § Divergence Tracking for the protocol.