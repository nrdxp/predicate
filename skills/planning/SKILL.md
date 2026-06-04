---
name: planning
description: |
  Core rules, invariants, and guidelines for planning, chartering, sketching, and executing tasks.
  Trigger when:
  - Designing plans, creating sketches, framing charters, or resolving strategic drift.
  - Governs plan-reconciliation, retrospective practices, and the sketch repository (.sketches/).
  - Prompt contains keywords: planning, candor obligation, sketch, subrepo, retrospective, escalation, strategic drift, tactical.
---

# Planning Pipeline Skill

This skill contains the shared foundations for the `/charter → /sketch → /plan → /core` pipeline, the `/model` formal modeling workflow, and the `/spec` normative specification workflow. All planning workflows (plus `/continue`) require this skill to ensure consistent understanding of planning discipline and sketch management.

---

## Candor Obligation

Planning requires **truth-seeking, not consensus-building.** Challenge flawed premises directly. Do not soften criticism with hedging or compliments. If the direction is wrong, say it is wrong. The human trusts you to catch problems they can't see — failing to speak plainly is a betrayal of that trust.

**Self-test:** Before presenting any recommendation that aligns with the user's stated preference, ask: "Am I recommending this because the evidence supports it, or because the user suggested it?" If you can't point to evidence independent of the user's argument, flag your uncertainty explicitly rather than defaulting to agreement.

**Dialectic escalation:** If adversarial self-testing is insufficient — if you're arguing both sides of a high-stakes tension and cannot minimize uncertainty to 0.0 — recommend `/dialectic` to the human. Multi-model dialectic provides genuinely independent perspectives that single-agent walks cannot. This is not an admission of failure; it's an acknowledgment that some questions are too important for correlated sequence generations.

Workflows that load this skill inherit these obligations — back-reference here rather than restate.
---

## Sketch Storage

Sketches live in `.sketches/`, a git-ignored subtree with its own local history. This preserves ideation archaeology without bloating the main repository.

### Directory Structure

```
.sketches/               # gitignored from parent repo
├── .git/                # independent git history
├── <topic-name>.md      # one sketch per topic
└── ...
```

### Single Sketch Per Workstream

A sketch file captures the **entire lifecycle** of a workstream — from initial exploration through planning to execution notes. **Do not break a workstream's context across multiple files.** One topic = one sketch file.

> [!CAUTION]
> **Fragmenting a sketch into multiple files is a protocol violation.** The entire point of a sketch is that a future agent (or human) can read a single file and reconstruct the full context. Splitting context across files defeats this — it forces readers to hunt for related pieces, and makes git history harder to follow.

If a sketch grows large, that's fine — length is cheap; lost context is expensive. Use headings and sections to organize within the file. The sketch's git commit history provides version granularity; the file itself provides context unity.

### Initialization

If `.sketches/` does not exist, initialize it as a git subtree:

```bash
# 1. Ensure .sketches/ is in .gitignore
echo '.sketches/' >> .gitignore

# 2. Create the directory
mkdir -p .sketches

# 3. Initialize as independent git repository
cd .sketches && git init

# 4. Create initial commit
echo "# Sketches" > README.md
git add README.md
git commit -m "init: sketch repository"
```

> [!NOTE]
> The `.sketches/` directory is a **git subtree** — it has its own `.git/` and history, completely independent of the parent repository. This allows iteration tracking on exploratory work without polluting the main project's history.

### Naming Convention

`YYYY-MM-DD-<topic-name>.md` — date-prefixed, lowercase, hyphenated, descriptive.

### Cross-Branch Awareness

When the sketch repository uses per-project branches (a shared repo with one branch per project), check for existing branches that relate to the current domain before creating a new sketch. Prior art from related projects may reveal solved problems, known dead ends, or reusable patterns.

This is **advisory, not blocking** — don't read 50 branches. But report what you found (or didn't find) in the sketch preamble so the decision to skip prior art is explicit, not accidental.

---

## Sketch Commit Discipline

Every modification to a sketch file MUST be immediately followed by a `git commit` within the `.sketches/` subrepo. **Every touch = a commit.** This creates a linear changelog of all decisions, findings, and pivots — an agentic history of the thought process.

- Commit **after every state transition**
- Commit **after every significant finding** or change in direction
- Commit **before any HALT point**
- Commit messages should be descriptive: `"sketch: added approach C (hybrid)"`, not `"update sketch"`

> [!CAUTION]
> **Commit Hygiene is a constant constraint.** All git commits (in both the main repository and the sketches sub-repository) must strictly follow the conventional format specified in [commit-hygiene](file:///var/home/nrd/git/github.com/nrdxp/predicate/skills/commit-hygiene/SKILL.md). Any commit message that violates conventional guidelines represents a failure of this constant constraint.

### Content Philosophy

The YAML grammar in each workflow is a **scaffold, not a cage**. The sketch acts as a **Dynamic Sketchpad** to track:
- **The Rubric ledger:** Context-specific qualitative and architectural goals mapping the target attractor basin. Rubric goals, metrics, and satisfiability conditions can be dynamically added, refined, or modified as details unfold. Any substantive goal shifts or rubric modifications that occur during execution must be compiled and explicitly highlighted in the final review or report presented to the human.
- **The Constraint ledger:** Micro-constraints sourced from human prompts, specific design skills (`hickey`/`lowy`), and programming guidelines.
- **The Unknowns ledger:** Gaps in context surfaced as work occurs.
- **Standards compliance checklists:** Invariant design and style standards checks.
- **Git commit details:** Metadata tracing work in real-time.

Sketches should capture anything a future agent would need to go from **zero to full context** at any point in the project:

> [!IMPORTANT]
> **The YAML grammar belongs in chat and sketches — not in committed plan documents.** The grammar is valuable for tracking state during conversation (REFINE, CHALLENGE, SCOPE) and for capturing context in sketches. But the committed plan artifact — the file that gets checked into the repository — MUST use `templates/PLAN.md`. A plan document that reproduces the YAML grammar instead of the template structure is malformed.

- Rubric goal states (PENDING, SATISFIED, UNSATISFIED), constraint states (PENDING, SATISFIED, VIOLATED), and evidence
- Unknowns tracker (OPEN, RESOLVED) and resolution traces
- Standards compliance checks (Hickey simplicity, Lowy volatility, language conventions)
- Rejected paths and why they were rejected
- Surprising discoveries or environmental constraints
- Links to relevant conversations, documents, or prior work
- User feedback and how it changed direction

**Be generous with context — the cost of recording too much is negligible; the cost of losing context is severe.**

### Update Cadence

The sketch is a **living document** throughout the full lifecycle:

| Phase     | When to Update Sketch                             |
| :-------- | :------------------------------------------------ |
| `/sketch` | Every state transition, every finding             |
| `/plan`   | Every challenge finding, every refinement         |
| `/model`  | Formalism selection rationale, validation results |
| `/spec`   | Constraint identification, verification results  |
| `/core`   | Every commit boundary (update constraints, log unknowns, evaluate standards, record commit metadata before executing commit), every unexpected discovery |

Every update MUST be committed to the `.sketches/` subrepo immediately.

---

## Sketch as Lifecycle Journal

The sketch is not abandoned after `/plan` begins. It remains a **living document** throughout the full lifecycle:

| Phase     | Sketch Role                                        |
| :-------- | :------------------------------------------------- |
| `/sketch` | Ideation, divergence, convergence                  |
| `/plan`   | Challenge findings written back                    |
| `/model`  | Domain formalization findings, validation results  |
| `/spec`   | Normative constraints identified, verified results |
| `/core`   | Dynamic Sketchpad ledger updates, execution notes appended |

### Execution Notes Format

When `/core` completes a phase, append to the sketch:

```markdown
## EXECUTION Notes (from /core)

### Phase N: [Name]

- Completed: [date]
- Changes: [what was done and why]
- Discoveries: [unexpected findings, if any]
- Pivots: [deviations from plan, if any]
- Dead Ends: [approaches attempted and abandoned, with why they failed — prevents future agents from retrying known failures]
- Debt: [any technical debt introduced — all items must also be recorded in the plan's Technical Debt section]
```

> [!IMPORTANT]
> The sketch provides complete archaeology: ideation → planning → execution. Future agents can review the entire thought chain by reading the sketch history. **If it's not in the sketch, it didn't happen.**

> [!TIP]
> Use `/git-review` on the `.sketches/` repository to review how planning and execution evolved. The sketch's git history shows the full decision-making journey.

---

## Divergence Tracking

If execution diverges from the plan:

1. Note the divergence in the sketch under EXECUTION Notes
2. **Update the plan** to reflect the new direction
3. This ensures the plan always reflects current goals

Record unexpected discoveries immediately — do not defer to phase end. If you learn something surprising mid-step, update the sketch before continuing.

---

## Strategic Escalation

Divergence from a plan is tactical — it's contained within the plan's scope and handled by the Deviation Log. But some deviations are **strategic** — they threaten the assumptions of upstream artifacts (charters, models, ADRs). Strategic drift requires immediate escalation, not silent absorption.

### Tactical vs. Strategic Evaluation

At any workflow boundary where deviation is detected, evaluate:

- **Tactical drift:** The deviation changes *how* the work is done but stays within the plan's goals, the charter's NON_GOALS, and the charter's APPETITE. Record in the Deviation Log and continue.
- **Strategic drift:** The deviation violates a charter NON_GOAL, pushes past APPETITE, contradicts the NORTH_STAR, invalidates a formal model's assumptions, or renders an ADR's rationale obsolete. This requires ESCALATION.

**Examples to sharpen the boundary:**

- *Tactical:* Switching from `HashMap` to `BTreeMap` for deterministic iteration — changes implementation detail, stays within plan goals. Record in Deviation Log, continue.
- *Strategic:* Discovering the problem requires a relational database when the charter scoped a file-based store — violates architecture assumptions. ESCALATE.
- *Strategic:* Feature creep pushes estimated scope past the charter's APPETITE — threatens upstream budget constraint. ESCALATE.

### ESCALATION Block

When strategic drift is detected, emit an ESCALATION block and **HALT**:

```yaml
ESCALATION:
  TYPE: STRATEGIC_DRIFT
  ARTIFACT: "path/to/threatened/artifact"
  VIOLATION: "What upstream constraint is threatened"
  EVIDENCE: "The specific deviation or discovery that triggered this"
  RECOMMENDATION: [RE_CHARTER | DIALECTIC | DESCOPE]
```

**This is a HALT point.** The human decides the response path:

- **RE_CHARTER:** The strategic frame needs revision. Open a Reconciliation Sketch (see below).
- **DIALECTIC:** The tension is genuinely contested — neither the strategy nor the reality is clearly wrong. Escalate to `/dialectic` for multi-model arbitration.
- **DESCOPE:** The plan must be cut to fit within the existing strategy. Revise the plan's phases and re-enter `/core`.

> [!CAUTION]
> **Strategic deviation without ESCALATION is a protocol violation.** If `JUSTIFICATION.SCOPE.DELTA != UNCHANGED` and the deviation threatens an upstream artifact, silently absorbing it breaks the coherence of the entire artifact chain. The cost of a false-positive ESCALATION is a brief human review. The cost of silent strategic drift is artifact rot across charters, plans, models, and ADRs.

### Where ESCALATION Applies

ESCALATION is a **framework invariant**, not workflow-specific. Any workflow that interacts with reality closely enough to invalidate an upstream premise must be able to throw ESCALATION:

| Workflow    | Escalation Point                                                     |
| :---------- | :------------------------------------------------------------------- |
| `/core`     | Commit boundaries (when `SCOPE.DELTA != UNCHANGED`)                 |
| `/plan`     | CHALLENGE and SCOPE states (when phases violate charter constraints) |
| `/model`    | VALIDATE state (when domain math contradicts upstream artifacts)     |
| `/spec`     | VERIFY state (when spec contradicts model or charter)               |
| `/continue` | Commit boundaries (mirrors `/core`)                                 |

---

## Reconciliation Sketches

When ESCALATION fires and the human chooses **RE_CHARTER**, the response is a **Reconciliation Sketch** — a sketch with structured context that distinguishes it from normal exploration.

A normal sketch starts from: "What should we do about X?"
A reconciliation sketch starts from: "We believed X. Reality proved Y. What does this mean for artifacts A, B, C?"

### Reconciliation Context Template

A reconciliation sketch must open with this context block:

```markdown
## Reconciliation Context

### Trigger
- ESCALATION from: [commit/conversation reference]
- Type: STRATEGIC_DRIFT
- Evidence: [the specific deviation]

### Invalidated Assumption
- What we believed: [quote from charter/plan/model]
- What's actually true: [evidence from execution]

### Blast Radius
- Affected artifacts:
  - [ ] `docs/charters/X.md` — [what's threatened]
  - [ ] `docs/plans/Y.md` — [what's threatened]
  - [ ] `docs/models/Z.md` — [what's threatened]
  - [ ] `docs/adr/NNN.md` — [what's threatened]

### Direction (human decides)
- [ ] **AMEND STRATEGY** — bend the charter/model to fit what we learned
- [ ] **CONSTRAIN TACTICS** — descope the plan to stay within the original strategy
- [ ] **REFRAME** — the problem itself has changed; start a new charter cycle
```

### Exit Paths

Once the human approves a direction in PROPOSE:

- **AMEND STRATEGY:** The sketch converges on specific amendments to the affected upstream artifacts. The agent applies these amendments directly through normal commit discipline — no `/plan` required for text-level charter or model updates. After amendments are committed, the interrupted workflow resumes.
- **CONSTRAIN TACTICS:** The sketch converges on specific plan descoping. Amendments are recorded in the plan's Deviation Log. The interrupted workflow resumes with reduced scope.
- **REFRAME:** The sketch becomes the input to a new `/charter` cycle, with explicit reference to the old charter and what it got wrong. The interrupted workflow is abandoned.

> [!IMPORTANT]
> **Reconciliation vs. Dialectic:** Reconciliation sketches handle **empirical invalidation** — "reality proved us wrong, how do we adapt?" Dialectic handles **logical arbitration** — "we have two compelling theories and reality hasn't forced our hand yet." Default to reconciliation for strategic drift; escalate to `/dialectic` only when the tension is genuinely contested rather than empirically resolved.

---

## Retrospective

After all phases of a plan are executed, the sketch should have a final section that closes the loop on the lifecycle. This is not a separate workflow — it's the last chapter of the sketch's story.

```markdown
## RETROSPECTIVE

### Process

- Did the plan hold up? Where did we diverge and why?
- Were the estimates realistic?
- Did CHALLENGE catch the risks that actually materialized?

### Calibration

- Estimated phases: N  |  Actual: M
- Phases that held: [list]
- Phases that expanded: [list, with why]
- Biggest surprise: [what you could not have predicted]
- Process weight verdict: [was the full pipeline justified for this task?]

### Outcomes

- What unexpected debt was introduced? (Cross-reference JUSTIFICATION.DEBT items)
- What would we do differently next cycle?

### Pipeline Improvements

- Should any skill be updated based on this experience?
```

> [!TIP]
> Not every cycle warrants a full retrospective. Use judgment — but if the plan diverged significantly, if unexpected debt accumulated, or if you noticed a pattern that future agents should know about, write it down. The cost of overdocumenting is negligible; the cost of losing hard-won lessons is severe.

> [!IMPORTANT]
> The sketch captures **real-time execution notes** — observations made in the moment during each commit. When the plan's final phase is complete, **distill** those observations into the plan's `## Retrospective` section. The sketch is private (gitignored); the plan is committed and public. Hard-won lessons belong in the durable, publicly visible document.