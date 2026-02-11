# Predicate

Reusable agent axioms (rulesets) and workflows for agentic coding assistants.

## What's In Here

```
predicate/
├── axioms/      # Foundational rulesets (always active)
├── personas/    # Context-specific extensions (opt-in)
├── workflows/   # Manually-triggered SOPs
├── templates/   # Project templates (AGENTS.md, PLAN.md, etc.)
└── docs/        # Guides, plans, and ADRs
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

|            | `/charter` | `/sketch` | `/plan`     | `/core`     |
| :--------- | :--------- | :-------- | :---------- | :---------- |
| **Focus**  | frame      | explore   | stress-test | execute     |
| **Method** | declare    | diverge   | challenge   | verify      |
| **Output** | priorities | propose   | commit plan | commit code |

Each phase has its own workflow and mandatory halt points. They chain naturally, but your entry point depends on the scope of work — not every task needs every phase. A multi-cycle initiative starts with `/charter`. An unfamiliar problem starts with `/sketch`. A well-understood design can go straight to `/plan`. A small, well-scoped change can begin directly with `/core`. The pipeline provides structure where it's needed, not ceremony where it isn't.

---

#### `/charter` — Frame Before You Explore

**Purpose:** Define _why_ a project or initiative exists, _what_ success looks like, and _what's worth doing first_.

A charter is a **declaration**, not a process. There is no state machine — the divergence happens in sketches. The charter frames the strategic intent that guides them.

| Field           | What It Answers                                   |
| :-------------- | :------------------------------------------------ |
| **PURPOSE**     | What problem in the world does this solve?        |
| **NORTH_STAR**  | What does full success look like long-term?       |
| **WORKSTREAMS** | What's worth doing, in priority order?            |
| **NON_GOALS**   | What are we deliberately _not_ pursuing, and why? |
| **APPETITE**    | How much investment is this worth?                |

**Key mechanics:**

- **Workstreams spawn sketch cycles** — each workstream is independently explorable via `/sketch`. If it's too large to sketch, it's a sub-charter; too small, it's a plan item.
- **Strategic non-goals** — charter non-goals are strategic ("not our problem"), distinct from plan-level tactical non-goals ("not this phase").
- **Honest appetite** — not a deadline, but an investment tolerance. If work exceeds appetite, descope rather than push harder.

Charters are committed to `docs/charters/` as public, durable artifacts using `templates/CHARTER.md`.

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

#### `/core` — Zoom In and Execute

**Purpose:** Focus on a plan segment (2–3 commits), map the execution in detail, then implement — tracking divergence as it surfaces.

C.O.R.E. (**Context → Obstacles → Resolution → Execution**) takes each phase from the plan, maps it at a finer level of detail — specific files, clear verification goals, best-effort estimations — and then implements through a strict state machine:

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

#### `/doc` — Structured Documentation Lifecycle

**Purpose:** Deliberate documentation work — writing guides, auditing existing docs, or tackling documentation debt through a disciplined lifecycle.

| State      | What Happens                                                      |
| :--------- | :---------------------------------------------------------------- |
| **AUDIT**  | Catalogue existing docs. Identify debt, staleness, and gaps.      |
| **PLAN**   | Define deliverables with Divio quadrant and audience declared.    |
| **DRAFT**  | Write the documentation, applying the documentation axiom fully.  |
| **REVIEW** | Self-critique against axiom principles. Mechanical, not generous. |
| **VERIFY** | Present to human for approval.                                    |

**When to use `/doc` vs. the pipeline:**

- **Single document** (README, how-to guide) — invoke `/doc` directly
- **Multi-document restructuring** — use `/sketch` to explore architecture first, then `/doc` for drafting
- **Documentation alongside code changes** — use `/core` for the code, `/doc` for the docs
- **Large documentation initiative** — use `/plan` to define phases, then `/doc` within each phase

The documentation axiom (`axioms/documentation.md`) governs writing quality automatically — Section 1 for all text, Section 2 when producing standalone documents. `/doc` adds the _process_ for deliberate documentation work.

---

#### The Sketch as Lifecycle Journal

The sketch is not abandoned when planning begins. It remains a **living document** across the full pipeline:

| Phase     | Sketch Role                                             |
| :-------- | :------------------------------------------------------ |
| `/sketch` | Ideation, divergence, convergence                       |
| `/plan`   | Challenge findings and refinements written back         |
| `/core`   | Execution notes, unexpected discoveries, divergence log |

Every modification is committed to `.sketches/` immediately — _every touch = a commit_. This creates a linear changelog of all decisions, findings, and pivots. Future agents (or humans) can reconstruct the entire thought chain by reviewing the sketch's git history.

> **The best code is no code.** We don't commit to building until we're confident the design is correct. Planning deserves the same rigor we bring to execution — and when planning reveals we shouldn't build at all, that's the best outcome.

---

## Getting Started

See [docs/getting-started.md](docs/getting-started.md) for installation (submodule, symlinks, or copy), configuration, and verification.

---

## Contributing

PRs welcome. See [docs/authoring.md](docs/authoring.md) for how to write custom axioms, personas, and workflows.

Predicate is designed to be forked. The composable structure makes it easy to add organization-specific rules, domain-specific workflows, or curated persona subsets without modifying upstream files.

## License

MIT
