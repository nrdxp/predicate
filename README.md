# Predicate

Reusable agent axioms (rulesets) and workflows for agentic coding assistants.

## What's In Here

```
predicate/
├── axioms/                  # Foundational rulesets (always active)
│   ├── engineering.md       # Base engineering ruleset
│   └── integral.md          # Holistic problem-solving
├── personas/                # Context-specific extensions (opt-in)
│   ├── go.md                # Go-specific idioms
│   ├── rust.md              # Rust-specific idioms
│   ├── typescript.md        # TS/JS-specific idioms
│   ├── depmap.md            # DepMap MCP server usage
│   ├── personalization.md   # User naming preferences
│   └── ...                  # See Available Personas below
├── workflows/               # Manually-triggered SOPs
│   ├── sketch.md            # Exploratory planning (SKETCH protocol)
│   ├── plan.md              # Rigorous planning (PLAN protocol)
│   ├── core.md              # Granular execution (C.O.R.E. protocol)
│   ├── ai-audit.md          # Audit AI-generated code
│   ├── humanizer.md         # Remove AI writing patterns
│   └── ...                  # See Available Workflows below
└── templates/               # Project templates
    ├── AGENTS.md            # AGENTS.md template for projects
    ├── ADR.md               # Architecture Decision Record template
    └── .gitignore           # Gitignore template (includes .sketches/)
```

### Terminology

| Term         | Description                                                                 |
| :----------- | :-------------------------------------------------------------------------- |
| **Axiom**    | A foundational ruleset. Any file in `axioms/` is always active — no opt-in. |
| **Persona**  | A context-specific extension in `personas/`. Opt-in and task-relevant.      |
| **Workflow** | A task-specific SOP, manually triggered via slash command.                  |

---

## Philosophy

### Why Predicate?

AI coding assistants need clear, consistent guidance, but system prompts quickly become unwieldy. Predicate separates concerns:

- **Axioms** → Engineering principles that apply everywhere
- **Personas** → Context-specific rules loaded only when relevant
- **Workflows** → Structured procedures triggered on demand

This prevents context overload. A Rust-focused request doesn't need Go idioms; a README update doesn't need language personas at all. The agent loads only what's relevant to the current task.

### Built on Standards

Predicate integrates with existing conventions rather than inventing new ones:

- **[AGENTS.md](https://agent.md)** — The emerging standard for project-level agent configuration
- **`.agent/` directory** — Common location recognized by agentic tools
- **Workflow triggers** — Slash commands familiar to most agent interfaces

### The Planning Pipeline

AI coding agents are powerful executors — but execution without disciplined planning produces fragile, misdirected work. The most common failure modes we see:

- **Ambiguity** — vague requirements silently interpreted by the agent, producing code that solves the wrong problem
- **Imprecise planning → imprecise execution** — if the plan is hand-wavy, the code will be too
- **Silent assumptions** — the agent "fills in the blanks" instead of surfacing unknowns, embedding invisible decisions that compound
- **Scope creep** — without explicit non-goals, work balloons until the agent runs out of context
- **Wasted implementation** — building before validating the design means discovering fundamental flaws in finished code

Predicate addresses these with a structured pipeline that separates _thinking_ from _doing_:

```
/sketch  →  /plan  →  /core
  explore      stress-test     execute
  diverge      challenge       verify
  propose      commit plan     commit code
```

Each phase has its own workflow, state machine, and mandatory halt points. They chain naturally but enforce boundaries — you can't skip ahead without meeting each phase's exit criteria.

---

#### `/sketch` — Explore Before You Commit

**Purpose:** Diverge before converging. Explore the problem space honestly before picking a direction.

SKETCH is deliberately low-fidelity. It moves through four states:

| State        | What Happens                                                         |
| :----------- | :------------------------------------------------------------------- |
| **EXPLORE**  | Understand the problem. Surface unknowns. _Block_ until resolved.    |
| **DIVERGE**  | Generate ≥2 meaningfully different approaches. No premature winners. |
| **CONVERGE** | Evaluate tradeoffs against explicit criteria. Form a recommendation. |
| **PROPOSE**  | Present the sketch draft to the human for approval.                  |

**Key mechanics:**

- **Unknowns gate progress** — if UNKNOWNS is non-empty, the agent is _forbidden_ from advancing. Questions get surfaced, not assumed away.
- **Alternatives are mandatory** — a single approach means you haven't explored enough.
- **Honest tradeoffs** — every approach must list cons. If you can't name them, you don't understand it.

Sketches live in `.sketches/`, a gitignored subtree with its own local git history. This preserves the full ideation record — every approach considered, every direction rejected — without bloating the main repo. Sketches are additive: new explorations create new files, revisions are committed locally, nothing is silently overwritten.

---

#### `/plan` — Stress-Test Before You Build

**Purpose:** Transform exploratory direction into an airtight execution blueprint. Actively seek reasons _not_ to proceed.

Where SKETCH explores possibilities, PLAN stress-tests the chosen direction. It moves through:

| State         | What Happens                                                             |
| :------------ | :----------------------------------------------------------------------- |
| **REFINE**    | Transform the sketch recommendation into a precise design specification. |
| **CHALLENGE** | Adversarial stress-test. Find reasons this will fail.                    |
| **SCOPE**     | Define explicit phases with concrete deliverables. Sharpen non-goals.    |
| **COMMIT**    | Present the complete plan + ADR for human approval.                      |

**The CHALLENGE phase is the heart of PLAN.** The agent becomes devil's advocate, using specific techniques:

- **Assumption Inversion** — "What if the opposite were true?"
- **Steel-Man the Alternative** — articulate the strongest case _for_ a rejected approach before dismissing it
- **Pre-Mortem** — "It's 3 months from now and this failed. Why?"
- **Intentional Malformation Check** — could the sketch's direction be subtly flawed or based on a misunderstanding?

CHALLENGE must identify ≥1 MEDIUM+ risk and evaluate ≥1 viable alternative with honest tradeoffs. A challenge phase that merely confirms the sketch is a failure mode.

The output is a committed plan artifact with phased deliverables, each designed to be independently valuable and sized for granular execution.

---

#### `/core` — Execute in Reviewable Chunks

**Purpose:** Granular, piecemeal implementation — 2–3 commits max per invocation.

C.O.R.E. (**Context → Obstacles → Resolution → Execution**) takes each phase from the plan and executes it through a strict state machine:

| State       | What Happens                                                             |
| :---------- | :----------------------------------------------------------------------- |
| **ABSORB**  | Ingest the phase objective and deliverables.                             |
| **CLARIFY** | Surface obstacles. _Forbidden_ from generating code if ambiguity exists. |
| **PLAN**    | Declare atomic steps with measurable verification conditions.            |
| **EXECUTE** | Implement, verify each step, halt at commit boundaries.                  |

**Key mechanics:**

- **Verification-first** — every step has a VERIFY assertion. No step is complete without it.
- **Commit boundaries are halt points** — the agent stops, presents a JUSTIFICATION block (approach rationale, scope delta, API impact, technical debt), and waits for human confirmation before continuing.
- **Debt transparency** — hacks and suboptimal solutions must be documented with reasoning and follow-up plans. Omitting known compromises is a protocol violation.
- **Recovery, not workarounds** — if verification fails or new ambiguity surfaces, the agent reverts to CLARIFY rather than pushing through.

---

#### The Sketch as Lifecycle Journal

The sketch is not abandoned when planning begins. It remains a **living document** across all three phases:

| Phase     | Sketch Role                                             |
| :-------- | :------------------------------------------------------ |
| `/sketch` | Ideation, divergence, convergence                       |
| `/plan`   | Challenge findings and refinements written back         |
| `/core`   | Execution notes, unexpected discoveries, divergence log |

Every modification is committed to `.sketches/` immediately — _every touch = a commit_. This creates a linear changelog of all decisions, findings, and pivots. Future agents (or humans) can reconstruct the entire thought chain by reviewing the sketch's git history.

> **The best code is no code.** We don't commit to building until we're confident the design is correct. Planning deserves the same rigor we bring to execution — and when planning reveals we shouldn't build at all, that's the best outcome.

---

## Installation

### Option 1: Git Submodule (Recommended)

Add predicate as a submodule at `.agent`:

```bash
# Add predicate as submodule
git submodule add https://github.com/nrdxp/predicate.git .agent

# Copy AGENTS.md template to project root
cp .agent/templates/AGENTS.md ./AGENTS.md

# Edit AGENTS.md: fill in project details, build commands, active personas, etc.
```

**Updating:**

```bash
git submodule update --remote .agent
```

### Option 2: Symlinks

Clone once, symlink into each project:

```bash
# Clone predicate somewhere
git clone https://github.com/nrdxp/predicate.git ~/predicate

# In your project
mkdir -p .agent
ln -s ~/predicate/axioms .agent/axioms
ln -s ~/predicate/personas .agent/personas
ln -s ~/predicate/workflows .agent/workflows

# Copy AGENTS.md template
cp ~/predicate/templates/AGENTS.md ./AGENTS.md
```

### Option 3: Copy

For projects that can't use submodules or symlinks:

```bash
cp -r /path/to/predicate/axioms .agent/axioms
cp -r /path/to/predicate/personas .agent/personas
cp -r /path/to/predicate/workflows .agent/workflows
cp /path/to/predicate/templates/AGENTS.md ./AGENTS.md
```

---

## Project Structure After Installation

```
your-project/
├── .agent/
│   ├── PREDICATE.md              # Predicate system documentation (read first)
│   ├── axioms/
│   │   ├── engineering.md        # Base ruleset (axiom, always active)
│   │   └── integral.md          # Holistic problem-solving (axiom)
│   ├── personas/                 # Context-specific (mark active in AGENTS.md)
│   │   ├── go.md
│   │   ├── rust.md
│   │   └── ...
│   └── workflows/
│       └── ...                   # Task-specific SOPs
└── AGENTS.md                     # Project context + active personas
```

---

## Configuring Active Personas

Not all personas apply to every project. In your project's `AGENTS.md`, specify which personas are active:

```markdown
**Active Personas:**

- Go idioms
- DepMap MCP usage
```

The agent will only load personas marked as active and relevant to the current request.

### Available Personas

| Persona              | Purpose                      |
| :------------------- | :--------------------------- |
| `go.md`              | Go language idioms           |
| `rust.md`            | Rust language idioms         |
| `typescript.md`      | TypeScript/JavaScript idioms |
| `depmap.md`          | DepMap MCP server usage      |
| `integral.md`        | Holistic problem-solving     |
| `personalization.md` | User naming preferences      |

---

## Available Workflows

| Workflow                                 | Trigger       | Description                                        |
| :--------------------------------------- | :------------ | :------------------------------------------------- |
| [sketch.md](workflows/sketch.md)         | `/sketch`     | Exploratory planning — diverge before converging   |
| [plan.md](workflows/plan.md)             | `/plan`       | Rigorous planning — stress-test before committing  |
| [core.md](workflows/core.md)             | `/core`       | Granular execution — C.O.R.E. protocol             |
| [ai-audit.md](workflows/ai-audit.md)     | `/ai-audit`   | 4-layer audit framework for AI-generated code      |
| [git-review.md](workflows/git-review.md) | `/git-review` | Review git history for coherence and scope drift   |
| [humanizer.md](workflows/humanizer.md)   | `/humanizer`  | Remove AI writing patterns; make text more natural |
| [predicate.md](workflows/predicate.md)   | `/predicate`  | Re-read global rules; combats context drift        |

Workflows can be chained: `/sketch + /plan + /core`

---

## Contributing

PRs welcome. When adding new content:

- **New axioms**: Add to `axioms/`
- **New personas**: Add to `personas/`
- **New workflows**: Add to `workflows/` with proper front-matter:
  ```yaml
  ---
  name: "Workflow Name"
  description: "One-line description"
  trigger: "/slash-command"
  ---
  ```

### Forking for Custom Rulesets

Predicate is designed to be forked. If you want to:

- Add organization-specific rules or personas
- Create domain-specific workflows
- Maintain a curated subset of personas

Fork this repo and use your fork as the submodule source. The composable structure makes it easy to extend without modifying upstream files.

## License

MIT
