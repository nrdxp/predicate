# Planning Pipeline Persona

This persona contains the shared foundations for the `/charter → /sketch → /plan → /core` pipeline and the `/model` formal modeling workflow. All planning workflows (plus `/continue`) require this persona via `required_personas:` to ensure consistent understanding of planning discipline and sketch management.

---

## Candor Obligation

Planning requires **truth-seeking, not consensus-building.** Challenge flawed premises directly. Do not soften criticism with hedging or compliments. If the direction is wrong, say it is wrong. The human trusts you to catch problems they can't see — failing to speak plainly is a betrayal of that trust.

**Self-test:** Before presenting any recommendation that aligns with the user's stated preference, ask: "Am I recommending this because the evidence supports it, or because the user suggested it?" If you can't point to evidence independent of the user's argument, flag your uncertainty explicitly rather than defaulting to agreement.

**Dialectic escalation:** If adversarial self-testing is insufficient — if you're arguing both sides of a high-stakes tension and can't resolve it with confidence — recommend `/dialectic` to the human. Multi-model dialectic provides genuinely independent perspectives that single-agent reasoning cannot. This is not an admission of failure; it's an acknowledgment that some questions are too important for correlated reasoning.

Workflows that load this persona inherit these obligations — back-reference here rather than restate.
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
> Modifying a sketch without committing is a **protocol violation**. The sketch's git history IS the decision record. If it's not committed, it didn't happen.

### Content Philosophy

The YAML grammar in each workflow is a **scaffold, not a cage**. Sketches should capture anything a future agent would need to go from **zero to full context** at any point in the project:

> [!IMPORTANT]
> **The YAML grammar belongs in chat and sketches — not in committed plan documents.** The grammar is valuable for tracking state during conversation (REFINE, CHALLENGE, SCOPE) and for capturing context in sketches. But the committed plan artifact — the file that gets checked into the repository — MUST use `templates/PLAN.md`. A plan document that reproduces the YAML grammar instead of the template structure is malformed.

- Problem framing and constraints discovered
- Rejected paths and why they were rejected
- Surprising discoveries or environmental constraints
- Links to relevant conversations, documents, or prior work
- Domain-specific context that wouldn't be obvious
- User feedback and how it changed direction

**Be generous with context — the cost of recording too much is negligible; the cost of losing context is severe.**

### Update Cadence

The sketch is a **living document** throughout the full lifecycle:

| Phase     | When to Update Sketch                             |
| :-------- | :------------------------------------------------ |
| `/sketch` | Every state transition, every finding             |
| `/plan`   | Every challenge finding, every refinement         |
| `/model`  | Formalism selection rationale, validation results |
| `/core`   | Every commit boundary, every unexpected discovery |

Every update MUST be committed to the `.sketches/` subrepo immediately.

---

## Sketch as Lifecycle Journal

The sketch is not abandoned after `/plan` begins. It remains a **living document** throughout the full lifecycle:

| Phase     | Sketch Role                                       |
| :-------- | :------------------------------------------------ |
| `/sketch` | Ideation, divergence, convergence                 |
| `/plan`   | Challenge findings written back                   |
| `/model`  | Domain formalization findings, validation results |
| `/core`   | Execution notes appended                          |

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
- Debt: [any technical debt introduced — MEDIUM+ items must also be recorded in the plan's Technical Debt section]
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

- Should any axiom/persona/workflow be updated based on this experience?
```

> [!TIP]
> Not every cycle warrants a full retrospective. Use judgment — but if the plan diverged significantly, if unexpected debt accumulated, or if you noticed a pattern that future agents should know about, write it down. The cost of overdocumenting is negligible; the cost of losing hard-won lessons is severe.

> [!IMPORTANT]
> The sketch captures **real-time execution notes** — observations made in the moment during each commit. When the plan's final phase is complete, **distill** those observations into the plan's `## Retrospective` section. The sketch is private (gitignored); the plan is committed and public. Hard-won lessons belong in the durable, publicly visible document.

