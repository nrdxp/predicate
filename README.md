# Predicate

Reusable agent rulesets (rules), skills, and workflows for agentic coding assistants.

👉 **[Proceed directly to the Getting Started Guide](docs/getting-started.md)** to integrate Predicate within your workspace.

## What's In Here

```
predicate/
├── skills/      # Encapsulated agent skills (rules, workflows, tools)
├── templates/   # Project templates (AGENTS.md, PLAN.md, etc.)
└── docs/        # Guides, plans, ADRs, and formal models
```

### Terminology

Under Predicate's unified architecture, all agent assets are packaged as **Skills**:

| Term | Category | Description |
| :--- | :--- | :--- |
| **Rule Skill** | Constraint | Declarative guidelines and guardrails (e.g. `rust`, `engineering`). |
| **Workflow Skill** | Procedure | Structured state-machine SOPs (e.g. `plan`, `core`, `dialectic` [MDCS]). |
| **Tool Skill** | Capability | Executable scripts or API maps (e.g. `depmap`, `security-audit`). |

---

## Philosophy

### Mathematical Formalism (Closed-Loop Stochastic Trajectory Control)

Predicate abandons heuristic, anthropomorphic "prompt engineering" in favor of a rigorous control-theoretic paradigm. Autoregressive language models do not "think" or "reason"; they execute a **Stochastic Walk** across a discrete token state-space. Predicate is designed to mathematically constrain, evaluate, and direct this walk.

#### 1. Autoregressive Sequence Walks
Autoregressive token generation is a deterministic walk across a stochastic transition graph:
$$P(\mathbf{S}_{t+1} \mid \mathbf{S}_t)$$
where the sequence prefix $\mathbf{S}_t = (x_0, x_1, \dots, x_t)$ defines the state of the system at step $t$.

#### 2. Prompts as Initial Boundary Conditions (IBC)
A prompt is not an instruction; it is an **Initial Boundary Condition (IBC)**—a high-density informational constraint vector that warps the probability landscape. The IBC prunes the token state-space to establish a deep **Attractor Basin**, forcing sequence momentum toward valid target configurations.

#### 3. Entropy and the Gibbs-Boltzmann Distribution
Token selection probability is governed by the Gibbs-Boltzmann distribution from statistical mechanics:
$$P(x_i) = \frac{\exp(z_i / \tau)}{\sum_j \exp(z_j / \tau)}$$
where $z_i$ represents the logits and $\tau$ is thermodynamic temperature. As $\tau \to 0$, structural entropy collapses, forcing the sequence walk into a deterministic local energy minimum (greedy decoding).

#### 4. Closed-Loop Feedback Control
Open-loop autoregressive generation has a mathematically guaranteed non-zero probability of diverging over long horizons, manifesting as compounding error vectors (stochastic drift/hallucination). To ensure convergence, Predicate implements **Closed-Loop Stochastic Trajectory Control**. We introduce external, deterministic validators (compilers, test runners, linters) to compute the error differential ($\Delta E_k = V(\mathbf{S}_k)$) and apply iterative, corrective feedback ($\Delta \mathbf{S}_{k+1}$) to drive the system toward a zero-error state:
$$\mathbf{S}_{k+1} = \mathbf{S}_k \oplus \Delta \mathbf{S}_{k+1}$$

---

### Evolving from Philosophy to Architecture: The Abstraction of Skills

Predicate translates this control-theoretic paradigm into concrete workspace configurations through modular, semantically loaded **Skills**. Rather than loading a monolithic prompt that dilutes the Initial Boundary Condition, Predicate indexes capabilities semantically to optimize sequence walks:

* **Phase-Space Constriction (Rule Skills):** Declarative guardrails (e.g., `rust`, `engineering`) that restrict the valid phase-space volume. By dynamically loading only context-specific rules, we prune unneeded state-space dimensions, lowering sequence entropy and preventing out-of-bounds exploration.
* **State-Transition Assertions (Workflow Skills):** Structured state-machine SOPs (e.g., `/plan`, `/core`) that constrain the state transition trajectory. Forcing the generation of intermediate step tokens (such as challenge logs and verification plans) induces a structured state-space expansion, lowering the conditional entropy of final implementation tokens.
* **Error-Differential Feedback (Tool Skills):** Executable validation scripts (e.g., `depmap`, `security-audit`) that act as the outer-loop feedback controllers. They execute the deterministic validator $V(\mathbf{S})$, report the error differential $\Delta E$, and inject the corrective feedback loop directly back into the sequence context to force convergence before commit staging.

### Built on Standards

Rather than fabricating proprietary configuration formats, Predicate aligns with emerging, industry-wide standards for agentic orchestration. The concepts of rules, workflows, and tools represent the tripartite architectural foundation toward which modern coding agents are converging. Predicate unifies these under the **Skills (Semantic Capabilities)** abstraction—self-contained packages of instructions and executable tools/scripts. These are modeled after standard agent capabilities, designed to be indexed semantically and called dynamically during tool-use phases.

- **[AGENTS.md](https://agents.md) & `.agents/` Directory** — Predicate acts as a concrete, shareable implementation of the `AGENTS.md` specification. It materializes active skills catalogs inside the `.agents/` directory—the standard workspace path recognized by compliant agentic platforms.

### The Planning Pipeline

AI coding agents execute fast — but execution without disciplined planning produces throwaway work. The most common failure modes:

- **Ambiguity** — vague requirements silently interpreted by the agent, producing code that solves the wrong problem
- **Imprecise planning → imprecise execution** — if the plan is hand-wavy, the code will be too
- **Silent assumptions** — the agent "fills in the blanks" instead of surfacing unknowns, embedding invisible decisions that compound
- **Scope creep** — without explicit non-goals, work balloons until the agent runs out of context
- **Wasted implementation** — building before validating the design means discovering fundamental flaws in finished code

Predicate addresses these with a structured pipeline that separates _planning_ from _execution_:

|            | `/charter` | `/sketch` | `/plan`     | `/model`     | `/core`     |
| :--------- | :--------- | :-------- | :---------- | :----------- | :---------- |
| **Focus**  | frame      | explore   | stress-test | formalize    | execute     |
| **Method** | declare    | diverge   | challenge   | construct    | verify      |
| **Output** | priorities | propose   | commit plan | commit model | commit code |

Each phase has its own workflow and mandatory halt points. They chain naturally, but your entry point depends on the scope of work — not every task needs every phase. A multi-cycle initiative starts with `/charter`. An unfamiliar problem starts with `/sketch`. A well-understood design can go straight to `/plan`. `/model` can be invoked at any point to formalize domain structure through the SDMA lens. A small, well-scoped change can begin directly with `/core`. The pipeline provides structure where it's needed, not ceremony where it isn't.

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

**Purpose:** Transform exploratory direction into an execution blueprint. Actively seek reasons _not_ to proceed.

Where SKETCH explores possibilities, PLAN stress-tests the chosen direction. It moves through:

| State         | What Happens                                                             |
| :------------ | :----------------------------------------------------------------------- |
| **REFINE**    | Transform the sketch recommendation into a precise design specification. |
| **CHALLENGE** | Adversarial stress-test. Find reasons this will fail.                    |
| **SCOPE**     | Define explicit phases with concrete deliverables. Sharpen non-goals.    |
| **COMMIT**    | Present the complete plan + ADR for human approval.                      |

**The CHALLENGE phase is the point of PLAN.** The agent becomes devil's advocate, using specific techniques:

- **Assumption Inversion** — "What if the opposite were true?"
- **Steel-Man the Alternative** — articulate the strongest case _for_ a rejected approach before dismissing it
- **Pre-Mortem** — "It's 3 months from now and this failed. Why?"
- **Intentional Malformation Check** — could the sketch's direction be subtly flawed or based on a representation mismatch?

CHALLENGE must identify ≥1 MEDIUM+ risk and evaluate ≥1 viable alternative with honest tradeoffs. A challenge phase that merely confirms the sketch is a failure mode.

The output is a committed plan artifact with phased deliverables, each designed to be independently valuable and sized for granular execution.

---

#### `/core` — Closed-Loop Stochastic Trajectory Control (C-LTC)

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
- **Debt transparency** — hacks and suboptimal solutions must be documented with justification and follow-up plans. Omitting known compromises is a protocol violation.
- **Recovery, not workarounds** — if verification fails or new ambiguity surfaces, the agent reverts to CLARIFY rather than pushing through.

---

#### `/model` — Formalize Domain Ontology

**Purpose:** Apply formal mathematical modeling to a problem domain — either creating new model documents or scrutinizing existing specifications through the SDMA lens.

MODEL operates in two modes:

| Mode       | What Happens                                                                            |
| :--------- | :-------------------------------------------------------------------------------------- |
| **Create** | Produce a new formal model document from `templates/MODEL.md` to `docs/models/`         |
| **Apply**  | Scrutinize an existing document (protocol spec, whitepaper, etc.) through the SDMA lens |

**6-step procedure:** IDENTIFY → SELECT → CONSTRUCT → VALIDATE → RECORD → CONNECT. The SDMA rule provides a starting toolkit (categorical, coalgebraic, linear, information-theoretic formalisms), but any mathematical formalism is available. The governing principle is **minimal representation**: choose the simplest formalism that faithfully captures the domain's structure.

**Key mechanics:**

- **HALT after SELECT** — formalism choice must be approved before construction begins
- **Decision Matrix as starting point** — the SDMA's matrix covers critical isomorphisms, but domains may call for formalisms beyond it
- **Template discipline** — create mode documents use `templates/MODEL.md`; apply mode may produce companion documents or integrated annotations

---

#### `/dialectic` — Multi-Distribution Cross-Sampling (MDCS)

Multi-Distribution Cross-Sampling (MDCS) maps protocol boundaries by sampling a proposition under opposing parameter biases to identify structural constraints.

| State           | What Happens                                                                     |
| :-------------- | :------------------------------------------------------------------------------- |
| **FRAME**       | Define the falsifiable proposition and stakes. (Skipped if escalated from another workflow.) |
| **D_ALPHA**     | Sample the token space under a positive parameter bias ($D_\alpha$). HALT for model switch. |
| **D_BETA**      | Sample the token space under an adversarial negative parameter bias ($D_\beta$). HALT for model switch. |
| **BARYCENTRIC** | Compute the intersection topology of both distributions to isolate unverified state dimensions (unknown unknowns). HALT for human decision. |

**Key mechanics:**

- **Model switching is mandatory** — each distribution transition is a HALT where the human switches to a different model, ensuring zero variance contamination.
- **Orthogonal parameter bias** — each distribution optimizes for variance coverage relative to its positive or negative bias.
- **Sketch-based distribution recovery** — on model switch, the new model reads the sketch's `CROSS_SAMPLING` block to recover the context and prior history.
- **Invocable standalone or via escalation** — any planning workflow can recommend `/dialectic` when a boundary tension exceeds single-agent resolution capacity.

#### `/doc` — Structured Documentation Lifecycle

**Purpose:** Deliberate documentation work — writing guides, auditing existing docs, or tackling documentation debt through a disciplined lifecycle.

| State      | What Happens                                                      |
| :--------- | :---------------------------------------------------------------- |
| **AUDIT**  | Catalogue existing docs. Identify debt, staleness, and gaps.      |
| **PLAN**   | Define deliverables with Divio quadrant and audience declared.    |
| **DRAFT**  | Write the documentation, applying the documentation rule fully.  |
| **REVIEW** | Self-critique against rule principles. Mechanical, not generous. |
| **VERIFY** | Present to human for approval.                                    |

**When to use `/doc` vs. the pipeline:**

- **Single document** (README, how-to guide) — invoke `/doc` directly
- **Multi-document restructuring** — use `/sketch` to explore architecture first, then `/doc` for drafting
- **Documentation alongside code changes** — use `/core` for the code, `/doc` for the docs
- **Large documentation initiative** — use `/plan` to define phases, then `/doc` within each phase

The documentation rule (`skills/documentation/SKILL.md`) governs writing quality automatically — Section 1 for all text, Section 2 when producing standalone documents. `/doc` adds the _process_ for deliberate documentation work.

---

#### The Sketch as Lifecycle Journal

The sketch is not abandoned when planning begins. It remains a **living document** across the full pipeline:

| Phase      | Sketch Role                                             |
| :--------- | :------------------------------------------------------ |
| `/charter`    | Strategic context that frames sketch cycles               |
| `/sketch`     | Ideation, divergence, convergence                         |
| `/plan`       | Challenge findings and refinements written back           |
| `/model`      | Formalization findings written back to active sketch      |
| `/dialectic`  | Multi-distribution cross-sampling and barycentric maps recorded |
| `/core`       | Execution notes, unexpected discoveries, divergence log   |

Every modification is committed to `.sketches/` immediately — _every touch = a commit_. This creates a linear changelog of all decisions, findings, and pivots. Anyone can reconstruct the full thought chain from the sketch's git history.

> **The best code is no code.** We don't commit to building until the design is right. When planning reveals we shouldn't build at all, that's the best outcome.

### Key Trajectory Control Mechanisms

To prevent trajectory drift and fake pass declarations, Predicate implements the following core verification invariants:

* **Context-Specific Rubrics:** Every active sketch tracks a dynamic qualitative success ledger (`RUBRIC`) in its sketchpad. This ensures that the high-level purpose and architectural constraints are evaluated at every commit boundary, preventing Purpose Drift.
* **Iteration Transparency:** All manual-gate execution logs must output the exact iteration count, baseline verification failures ($\Delta E_0 \neq 0$), and intermediate corrections inside their `REVIEW` block to provide verifiable proof of closed-loop execution.
* **One-Shot Skepticism:** If verification passes on the first try (`LOOPS: 1`), the agent is required to execute and record a skeptical self-audit (`SKEPTICAL_AUDIT`) checking for hidden assumptions, spatial complecting (Hickey check), or temporal volatility leaks (Lowy check).

---

## Getting Started

Predicate can be deployed either globally as an agent plugin or locally as a project-level Git submodule. See [docs/getting-started.md](docs/getting-started.md) for detailed instructions on installation pathways, `AGENTS.md` configuration, and validation.

### Hierarchical Configuration

The [AGENTS.md standard](https://agents.md) supports hierarchical configuration. When working in a subdirectory, check for and read any `AGENTS.md` in that directory. Subdirectory rules supplement (not replace) the root configuration.

---

## Contributing

PRs welcome. See [docs/authoring.md](docs/authoring.md) for how to write custom rules, skills, and workflows.

Predicate is designed to be forked. The composable structure makes it easy to add organization-specific rules, domain-specific workflows, or curated rule/skill subsets without modifying upstream files.

## License

MIT
