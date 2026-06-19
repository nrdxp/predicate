# Predicate

Modular rules, skills, and workflows to configure and constrain AI coding assistants.

See the [Getting Started Guide](docs/getting-started.md) to integrate Predicate into your project.

## Repository structure

```
predicate/
├── skills/      # Encapsulated agent skills (rules, workflows, tools)
├── templates/   # Project templates (AGENTS.md, IBC.md, etc.)
└── docs/        # Guides, plans, ADRs, and formal models
```

### Terminology

Predicate packages all agent assets as **skills**:

| Term | Category | Description |
| :--- | :--- | :--- |
| **Rule** | Constraint | Declarative guardrails (like `rust` or `engineering` guidelines). |
| **Workflow** | Procedure | State-machine SOPs (like `core`, `refine`, or `/dialectic` [MDCS]). |
| **Tool** | Capability | Executable scripts (like `depmap` or `security-audit`). |

---

## Philosophy: Closed-loop trajectory control

Prompt engineering is a fragile way to program. Autoregressive language models do not "think" or "reason"; they execute a stochastic walk across a discrete token state-space. Over long generations, errors compound. Without external constraints, an agent will eventually drift off course, write unverified code, or introduce regressions.

Predicate models the agent's prompt as an **Initial Boundary Condition (IBC)** that warps the probability landscape, carving a deep attractor basin to guide token selection. To keep the agent within this basin, we use **closed-loop feedback control**:

1. **Stochastic walks:** Token generation is a walk across a transition graph: $P(\mathbf{S}\_{t+1} \mid \mathbf{S}\_t)$, where the prefix sequence $\mathbf{S}\_t$ defines the state at step $t$.
2. **Entropy control:** Token selection uses the Gibbs-Boltzmann distribution:
   $$P(x\_i) = \frac{\exp(z\_i / \tau)}{\sum\_j \exp(z\_j / \tau)}$$
   where $z\_i$ represents the logits and $\tau$ is thermodynamic temperature. Lowering temperature collapses entropy, forcing deterministic local optimization.
3. **Closed-loop feedback:** An open-loop agent will eventually drift. Predicate closes the loop by running external, deterministic validators (compilers, linters, test runners). We capture the validator's output as an error differential ($\Delta E$) and inject corrective prompt feedback ($\Delta \mathbf{S}\_{k+1}$) to drive the system to a zero-error state:
   $$\mathbf{S}\_{k+1} = \mathbf{S}\_k \oplus \Delta \mathbf{S}\_{k+1}$$

---

### Evolving from math to code: The skill abstraction

Predicate translates this control-theoretic paradigm into concrete workspace configurations through modular **skills** loaded dynamically based on the active task:

* **Rules (phase-space constriction):** Declarative guardrails (like language styles) prune unneeded state-space dimensions. This lowers sequence entropy and prevents the model from wandering into invalid APIs.
* **Workflows (state-transition bounds):** State-machine SOPs (like `/sketch` or `/core`) force the agent to generate intermediate step tokens (such as exploration logs or verification plans). This induces a structured state-space expansion that lowers the conditional entropy of the final code.
* **Tools (error-differential feedback):** Executable validation scripts act as the outer-loop feedback controller. They run the validator, report the error vector, and loop until the validation error reaches zero.

---

### How Predicate works in practice

Predicate implements this feedback loop through three concrete mechanisms:

* **Test-driven invariants (TDD-first):** Before modifying any codebase files, the agent must translate spec invariants into a test. The test must produce a baseline failure ($\Delta E\_0 \neq 0$) to verify that the validation boundary is active.
* **The local optimization loop:** During execution, the agent runs a local loop: edit the code, run the validator, capture the error differential ($\Delta E\_k$), and adjust. This loop repeats (up to 3–5 times) until the error converges to zero.
* **The trajectory commit gate:** When the local loop converges, the agent checks the diff against architectural guidelines (Hickey simplicity, Lowy volatility) and the active sketch's rubric. If it passes (quality score = 1.0), the changes are staged. Under `CONTROL_MODE: AUTOMATIC`, the runner commits the change and moves to the next step. If it fails or times out, the runner halts, preserves the unverified draft changes for inspection, and hands control back to manual mode.

---

### Integration and standards

Predicate implements the [AGENTS.md specification](https://agents.md). Instead of inventing proprietary formats, it exposes rules, workflows, and tools inside the `.agents/` directory. Compliant coding platforms read this directory to discover and run local workspace skills.

### The planning pipeline

Left unchecked, coding agents optimize for speed over design coherence. They interpret vague requirements silently, make hidden assumptions, creep scope, and write throwaway code. 

Predicate prevents this by separating exploration from execution:

| Phase | `/sketch` | `/model` | `/core` | `/refine` |
| :--- | :--- | :--- | :--- | :--- |
| **Focus** | Explore | Formalize | Execute | Optimize |
| **Method** | Diverge | Construct | Verify | Polish |
| **Output** | Propose | Commit model | Commit code | Commit refinement |

Each phase has its own workflow and halt points. You only use what you need: an unfamiliar problem starts with `/sketch`, a well-scoped change goes straight to `/core`, `/model` can be invoked anywhere to formalize domain boundaries, and `/refine` optimizes existing artifacts.

Above the pipeline sit two tier-aware workflows for working across heterogeneous model classes: `/boundary` manufactures and adversarially refines the prompt contract (IBC) before any expensive or autonomous walk launches, and `/campaign` lets an architect-class model frame the initiative, survey exhaustively, derive a mitigation plan, emit worker prompts routed to cheaper tiers, and judge the work that returns. Strategic framing and stress-test planning — what a standalone charter or plan once held — live inside `/campaign`'s ABSORB, SURVEY, and PLAN states, where they are produced and consumed in one architect pass.

---

#### `/sketch` — Explore before you commit

Forces the agent to explore the problem space before selecting an implementation path. A sketch moves through four states:

1. **EXPLORE:** Research the problem. Surface unknowns. The agent is blocked from advancing if any unknowns remain unresolved.
2. **DIVERGE:** Generate at least two distinct approaches. Single-option designs are blocked.
3. **CONVERGE:** Evaluate tradeoffs and recommend a direction.
4. **PROPOSE:** Present the draft sketch to the human for feedback.

Sketches live in the git-ignored `.sketches/` directory, which maintains its own local git history. This preserves the archaeological thought process without bloating the main repository history.

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
2. **D_ALPHA:** Sample the sequence space under a positive parameter bias ($D\_\alpha$). Halt for model switch.
3. **D_BETA:** Sample the sequence space under an adversarial parameter bias ($D\_\beta$). Halt for model switch.
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

#### `/refine` — Automated refinement loop

A workflow for exhaustively auditing, optimizing, and polishing pre-existing codebase artifacts.

1. **ABSORB:** Ingest target artifacts, goals, and test suites. Scale loop limits ($N_{min}, M_{sweep}, K_{max}$) dynamically based on task complexity.
2. **AUDIT:** Analyze the artifact across correctness, API sufficiency, code quality, and edge cases. Actively consult project sibling skills and run the Socratic Purpose Checklist and Sieving & Cutting Audit.
3. **ITERATE:** Apply the local closed-loop TDD loop for each refinement target and commit.
4. **SWEEP:** Run multiple consecutive sweeps over the modified code space. Challenge zero-finding sweeps with the Adversarial Skepticism Rule and Sieving Sweep.
5. **REPORT:** Generate the final refinement report.

---

#### `/boundary` — Contract before you dispatch

Manufactures the Initial Boundary Condition (IBC) for an expensive or autonomous walk as the fixed point of a cheap refinement loop. A good boundary is optimized for **cheap rejection**, not guaranteed success: the receiving model must be able to refute a wrong frame in its first few hundred tokens.

Seven sufficiency conditions (S1–S7) govern every IBC: falsifiable premises, a first-class rejection genre, resolved/delegated/reserved decision rights, evaluator attachment (machine-checked proof at the top of the hierarchy), curated rather than paraphrased context, load-bearing vs plastic amendment rights, and boundary mass scaled to walker capability.

1. **DRAFT:** Author the candidate IBC from `templates/IBC.md` (cheap tier).
2. **ATTACK:** Independent adversarial reviewers object by citing violated sufficiency conditions; contested framings escalate to `/dialectic`.
3. **REVISE:** Amend or rebut with evidence; loop until an attack sweep yields zero grounded objections.
4. **APPROVE:** Mandatory human gate before dispatch.

---

#### `/campaign` — Orchestrate across model tiers

An architect-class model coordinates a multi-workstream goal as an hourglass: cheap boundary preparation, one expensive survey-and-planning pass, cheap disciplined execution.

1. **ABSORB:** Premise-audit the approved campaign IBC (rejecting the frame early is a success condition). Initialize the git-ignored `.scratch/<topic>/` working set.
2. **SURVEY:** Exhaustive multi-agent review fan-out; synthesize an evidence-grounded findings ledger.
3. **PLAN:** Derive a mitigation plan — a dependency graph of worker tasks, each mapped to the findings it mitigates.
4. **ORCHESTRATE:** Emit one IBC per task and route each to the cheapest capable model tier, assigning exactly one disciplining workflow (`/refine`, `/core`) per worker.
5. **DISPATCH ⇄ RECONCILE:** Workers execute autonomously and commit; the architect judges landed work with `/git-review` semantics and re-run evaluators, then re-verifies the premises of every pending prompt against current `HEAD` before further dispatch — realigning the living plan when reality diverges.
6. **CLOSE:** Full verification surface, a final adversarial sweep over the cumulative diff, and the campaign report.

---

#### `/chronicle` — Maintain project history

Maintains a persistent, high-level chronicle of the project's evolution in `docs/chronicle.md` using commit cutoff markers for cheap incremental updates.

1. **PREPARE:** Run `update_chronicle.py --prepare` to fetch a batch of commits since the last recorded SHA cutoff, ending at a `TARGET_END_SHA`.
2. **SUMMARIZE:** Conceptualize and group the batch's commits into design decisions, features, workflows, quality adjustments, and documentation.
3. **WRITE:** Run `update_chronicle.py --write --end-sha <TARGET_END_SHA> --summary "<markdown>"` to append the summary to `docs/chronicle.md` and advance the cutoff SHA in its frontmatter to the summarized range's end.
4. **REPEAT:** Iterate until the prepare command reports that the chronicle is up to date.

---

### The sketch as a lifecycle journal

The sketch is not discarded when implementation begins; it serves as a living record across all workflows:

| Phase | Sketch Role |
| :--- | :--- |
| `/sketch` | Direct ideation and design proposals |
| `/model` | Domain formalizations and mathematical maps |
| `/dialectic` | Cross-sampling traces and barycentric intersections |
| `/core` | Live execution notes, discoveries, and divergence logs |
| `/refine` | Refinement ledgers, sweep traces, and convergence history |
| `/boundary` | Sufficiency objections, revisions, and the approved contract |
| `/campaign` | Reconcile checkpoints — enough to regenerate `.scratch/` from sketch + git |

Every modification is committed to `.sketches/` immediately. This creates a linear git history of all architectural decisions, discoveries, and pivots.

---

### Invariants and trajectory safety

Predicate uses three constraints to prevent agents from declaring fake passes or drifting:

* **Rubrics:** Active sketches track a live `RUBRIC` ledger. High-level project goals and constraints are evaluated at every commit boundary to prevent purpose drift.
* **Iteration transparency:** Execution logs in `REVIEW` blocks must output the exact loop iteration count, the baseline verification failure details ($\Delta E\_0 \neq 0$), and any corrections applied.
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
