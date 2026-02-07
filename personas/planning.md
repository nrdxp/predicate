# Planning Pipeline Persona

This persona contains the shared foundations for the `/sketch → /plan → /core` pipeline. All three workflows (plus `/continue`) require this persona via `required_personas:` to ensure consistent understanding of planning discipline and sketch management.

---

## Planning Philosophy

**The best code is no code.** Before we build, we must understand why we're building — and whether we should build at all.

Planning deserves the same rigor we bring to execution. Every line of code that doesn't need to exist is a line that never needs debugging, documenting, or explaining. The goal isn't to avoid work; it's to avoid _wasted_ work.

This philosophy drives the entire pipeline:

- **Diverge before converging** — generate alternatives before picking one
- **Surface unknowns early** — better to discover blockers now than mid-implementation
- **Rigor over speed** — better to delay than to execute on a flawed design
- **Explicit scope** — non-goals are as important as goals

> The best plan is the one that reveals we shouldn't build at all — or that we should build something smaller, simpler, more purposeful.

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

`YYYY-MM-DD-<topic-name>.md` — date-prefixed, lowercase, hyphenated, descriptive. The date prefix gives readers an at-a-glance understanding of when the sketch cycle started.

Examples:

- `2026-02-07-auth-system-redesign.md`
- `2026-01-15-api-versioning-strategy.md`
- `2026-02-01-dependency-reduction.md`

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
| `/core`   | Every commit boundary, every unexpected discovery |

Every update MUST be committed to the `.sketches/` subrepo immediately.

---

## Sketch as Lifecycle Journal

The sketch is not abandoned after `/plan` begins. It remains a **living document** throughout the full lifecycle:

| Phase     | Sketch Role                       |
| :-------- | :-------------------------------- |
| `/sketch` | Ideation, divergence, convergence |
| `/plan`   | Challenge findings written back   |
| `/core`   | Execution notes appended          |

### Execution Notes Format

When `/core` completes a phase, append to the sketch:

```markdown
## EXECUTION Notes (from /core)

### Phase N: [Name]

- Completed: [date]
- Changes: [what was done and why]
- Discoveries: [unexpected findings, if any]
- Pivots: [deviations from plan, if any]
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
