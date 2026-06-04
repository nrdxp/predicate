# Predicate

Modular rules, skills, and workflows to configure and constrain AI coding assistants.

See the [Getting Started Guide](docs/getting-started.md) to integrate Predicate into your project.

## Repository structure

```
predicate/
├── skills/      # Encapsulated agent skills (rules, workflows, tools)
├── templates/   # Project templates (AGENTS.md, PLAN.md, etc.)
└── docs/        # Guides, plans, ADRs, and formal models
```

### Terminology

Predicate packages all agent assets as **skills**:

| Term | Category | Description |
| :--- | :--- | :--- |
| **Rule** | Constraint | Declarative guardrails (like `rust` or `engineering` guidelines). |
| **Workflow** | Procedure | State-machine SOPs (like `plan`, `core`, or `/dialectic` [MDCS]). |
| **Tool** | Capability | Executable scripts (like `depmap` or `security-audit`). |

---

## Philosophy: Closed-loop trajectory control

Prompt engineering is a fragile way to program. Autoregressive language models do not "think" or "reason"; they execute a stochastic walk across a discrete token state-space. Over long generations, errors compound. Without external constraints, an agent will eventually drift off course, write unverified code, or introduce regressions.

Predicate models the agent's prompt as an **Initial Boundary Condition (IBC)** that warps the probability landscape, carving a deep attractor basin to guide token selection. To keep the agent within this basin, we use **closed-loop feedback control**:

1. **Stochastic walks:** Token generation is a walk across a transition graph: $P(\mathbf{S}_{t+1} \mid \mathbf{S}_t)$, where the prefix sequence $\mathbf{S}_t$ defines the state at step $t$.
2. **Entropy control:** Token selection uses the Gibbs-Boltzmann distribution:
   $$P(x_i) = \frac{\exp(z_i / \tau)}{\sum_j \exp(z_j / \tau)}$$
   where $z_i$ represents the logits and $\tau$ is thermodynamic temperature. Lowering temperature collapses entropy, forcing deterministic local optimization.
3. **Closed-loop feedback:** An open-loop agent will eventually drift. Predicate closes the loop by running external, deterministic validators (compilers, linters, test runners). We capture the validator's output as an error differential ($\Delta E$) and inject corrective prompt feedback ($\Delta \mathbf{S}_{k+1}$) to drive the system to a zero-error state:
   $$\mathbf{S}_{k+1} = \mathbf{S}_k \oplus \Delta \mathbf{S}_{k+1}$$

---

### Evolving from math to code: The skill abstraction

Predicate translates this control-theoretic paradigm into concrete workspace configurations through modular **skills** loaded dynamically based on the active task:

* **Rules (phase-space constriction):** Declarative guardrails (like language styles) prune unneeded state-space dimensions. This lowers sequence entropy and prevents the model from wandering into invalid APIs.
* **Workflows (state-transition bounds):** State-machine SOPs (like `/plan` or `/core`) force the agent to generate intermediate step tokens (such as challenge logs or verification plans). This induces a structured state-space expansion that lowers the conditional entropy of the final code.
* **Tools (error-differential feedback):** Executable validation scripts act as the outer-loop feedback controller. They run the validator, report the error vector, and loop until the validation error reaches zero.

---

### How Predicate works in practice

Predicate implements this feedback loop through three concrete mechanisms:

* **Test-driven invariants (TDD-first):** Before modifying any codebase files, the agent must translate spec invariants into a test. The test must produce a baseline failure ($\Delta E_0 \neq 0$) to verify that the validation boundary is active.
* **The local optimization loop:** During execution, the agent runs a local loop: edit the code, run the validator, capture the error differential ($\Delta E_k$), and adjust. This loop repeats (up to 3–5 times) until the error converges to zero.
* **The trajectory commit gate:** When the local loop converges, the agent checks the diff against architectural guidelines (Hickey simplicity, Lowy volatility) and the active sketch's rubric. If it passes (quality score = 1.0), the changes are staged. Under `CONTROL_MODE: AUTOMATIC`, the runner commits the change and moves to the next step. If it fails or times out, the runner halts, preserves the unverified draft changes for inspection, and hands control back to manual mode.

---

### Integration and standards

Predicate implements the [AGENTS.md specification](https://agents.md). Instead of inventing proprietary formats, it exposes rules, workflows, and tools inside the `.agents/` directory. Compliant coding platforms read this directory to discover and run local workspace skills.

### The planning pipeline

Left unchecked, coding agents optimize for speed over design coherence. They interpret vague requirements silently, make hidden assumptions, creep scope, and write throwaway code. 

Predicate prevents this by separating planning from execution:

| Phase | `/charter` | `/sketch` | `/plan` | `/model` | `/core` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Focus** | Frame | Explore | Stress-test | Formalize | Execute |
| **Method** | Declare | Diverge | Challenge | Construct | Verify |
| **Output** | Priorities | Propose | Commit plan | Commit model | Commit code |

Each phase has its own workflow and halt points. You only use what you need: a large initiative starts with `/charter`, an unfamiliar problem starts with `/sketch`, a well-scoped change goes straight to `/core`, and `/model` can be invoked anywhere to formalize domain boundaries.

---

#### `/charter` — Frame before you explore

Defines *why* a project exists, what success looks like, and what workstreams to prioritize.

A charter is a strategic declaration committed to `docs/charters/` using `templates/CHARTER.md`. It has no state machine. Instead, it defines:

* **Purpose:** The core problem this project solves.
* **North star:** The long-term success criteria.
* **Workstreams:** Prioritized list of tasks (each workstream is explored via `/sketch`).
* **Non-goals:** Strategic boundaries (what we are deliberately not doing).
* **Appetite:** The maximum investment budget. If a workstream exceeds its appetite, we descope it.

---

#### `/sketch` — Explore before you commit

Forces the agent to explore the problem space before selecting an implementation path. A sketch moves through four states:

1. **EXPLORE:** Research the problem. Surface unknowns. The agent is blocked from advancing if any unknowns remain unresolved.
2. **DIVERGE:** Generate at least two distinct approaches. Single-option designs are blocked.
3. **CONVERGE:** Evaluate tradeoffs and recommend a direction.
4. **PROPOSE:** Present the draft sketch to the human for feedback.

Sketches live in the git-ignored `.sketches/` directory, which maintains its own local git history. This preserves the archaeological thought process without bloating the main repository history.

---

#### `/plan` — Stress-test before you build

Translates a sketch recommendation into an execution blueprint. While `/sketch` explores options, `/plan` tries to break them:

1. **REFINE:** Convert the recommendation into a precise design specification.
2. **CHALLENGE:** Actively try to find reasons the design will fail. The agent uses assumption inversion, steel-manning alternatives, and pre-mortems. It must identify at least one medium-to-high risk.
3. **SCOPE:** Break the work into concrete execution phases and tactical non-goals.
4. **COMMIT:** Present the final plan and Architecture Decision Records (ADRs) for approval.

---

#### `/core` — Execution state machine

Maps and executes granular plan steps (usually 2–3 commits at a time). It operates as a strict state machine:

1. **ABSORB:** Ingest the phase deliverables.
2. **CLARIFY:** Call out ambiguities. Coding is blocked while ambiguities exist.
3. **PLAN:** Declare atomic commits and their associated validation tests.
4. **EXECUTE:** Run the local TDD optimization loop, verify each step, and halt at commit boundaries to present review blocks.

Hacks and technical debt are allowed, but they must be documented in a visible `JUSTIFICATION` block at the commit boundary. Omitting known debt is a protocol violation.

---

#### `/model` — Formalize domain ontologies

Builds mathematical domain models or analyzes existing specifications using the Structured Domain Modeling Architecture (SDMA).

* **Create mode:** Creates a formal model file in `docs/models/` using `templates/MODEL.md`.
* **Apply mode:** Scrutinizes an external specification (protocol spec, whitepaper) through the SDMA lens.

The agent must halt after selecting a mathematical formalism (linear logic, coalgebra, category theory) to get human approval before building. The core constraint is minimal representation: select the simplest mathematics that faithfully captures the domain.

---

#### `/dialectic` — Multi-distribution cross-sampling

Arbitrates high-stakes logical tensions by sampling a proposition under opposing parameter biases:

1. **FRAME:** Define the falsifiable proposition.
2. **D_ALPHA:** Sample the sequence space under a positive parameter bias ($D_\alpha$). Halt for model switch.
3. **D_BETA:** Sample the sequence space under an adversarial parameter bias ($D_\beta$). Halt for model switch.
4. **BARYCENTRIC:** Intersect the two distributions to isolate unresolved unknowns.

Each transition is a mandatory halt point where the human switches to a different LLM. This prevents token-variance contamination between distributions.

---

#### `/doc` — Structured documentation

A workflow for writing guides, fixing documentation debt, or auditing existing reference files.

1. **AUDIT:** Catalogue existing docs and identify gaps.
2. **PLAN:** Define document deliverables using the Divio quadrant framework.
3. **DRAFT:** Write the content using the formatting rules in `skills/documentation/SKILL.md`.
4. **REVIEW:** Self-audit the text.
5. **VERIFY:** Present the docs for final approval.

---

### The sketch as a lifecycle journal

The sketch is not discarded when implementation begins; it serves as a living record across all workflows:

| Phase | Sketch Role |
| :--- | :--- |
| `/charter` | Strategic framing context |
| `/sketch` | Direct ideation and design proposals |
| `/plan` | Challenge findings and design refinements |
| `/model` | Domain formalizations and mathematical maps |
| `/dialectic` | Cross-sampling traces and barycentric intersections |
| `/core` | Live execution notes, discoveries, and divergence logs |

Every modification is committed to `.sketches/` immediately. This creates a linear git history of all architectural decisions, discoveries, and pivots.

---

### Invariants and trajectory safety

Predicate uses three constraints to prevent agents from declaring fake passes or drifting:

* **Rubrics:** Active sketches track a live `RUBRIC` ledger. High-level project goals and constraints are evaluated at every commit boundary to prevent purpose drift.
* **Iteration transparency:** Execution logs in `REVIEW` blocks must output the exact loop iteration count, the baseline verification failure details ($\Delta E_0 \neq 0$), and any corrections applied.
* **One-shot skepticism:** If a code change passes verification on the first try (`LOOPS: 1`), the agent must run an adversarial audit (`SKEPTICAL_AUDIT`) to check for hidden assumptions, spatial complecting (Hickey check), or volatility leaks (Lowy check).

---

## Getting started

Predicate runs either globally as an agent plugin or locally as a git submodule. See the [Getting Started Guide](docs/getting-started.md) for setup instructions.

### Hierarchical configuration

Predicate supports the [AGENTS.md standard](https://agents.md) hierarchical configuration. Subdirectories can contain their own `AGENTS.md` configurations to supplement (not replace) the rules defined at the root of the project.

---

## Contributing

Predicate is designed to be forked and customized. You can easily add organization-specific rules, workflows, or custom validators. See [docs/authoring.md](docs/authoring.md) to write your own skills.

## License

MIT
