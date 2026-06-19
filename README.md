# Predicate

Modular rules, skills, and workflows to configure and constrain AI coding assistants.

See the [Getting Started Guide](docs/getting-started.md) to integrate Predicate into your project.

## Repository structure

```
predicate/
├── rules.md     # The ambient ruleset: Prime Invariants every walker inherits
├── ambient.md   # Always-on principles that are not workflows (no entrypoint)
├── skills/      # Encapsulated agent skills (rules, workflows, tools)
├── ledger/      # Nickel contracts that make campaign artifacts machine-valid
├── gates/       # Standalone evaluator scripts (orphan, self-containment)
├── hooks/       # Git hooks that enforce the Commit Gate at commit time
├── templates/   # Project templates (AGENTS.md, IBC.md, ADR.md, etc.)
└── docs/        # Guides, the orchestration protocol, ADRs, and formal models
```

### Terminology

Predicate packages all agent assets as **skills**:

| Term | Category | Description |
| :--- | :--- | :--- |
| **Rule** | Constraint | Declarative guardrails (like `rust` or `engineering` guidelines). |
| **Workflow** | Procedure | State-machine SOPs (like `core`, `refine`, or `campaign`). |
| **Tool** | Capability | Executable scripts (like `depmap` or `security-audit`). |

---

## Philosophy: The Verification Dual

Prompt engineering is a fragile way to program. Autoregressive language models do not "think" or "reason"; they execute a stochastic walk across a discrete token state-space. Over long generations, errors compound. Without external constraints, an agent will eventually drift off course, write unverified code, or introduce regressions.

Predicate's core invariant is the **Verification Dual: verify, then trust.** No condition is ever closed by an agent's say-so. Every condition that must hold is closed by the strongest applicable evaluator, and exactly one of two complementary paths closes it:

* **The symbolic path.** If a deterministic evaluator exists or can be built — a proof, a type, a property test, an example test, a linter — it *must* be used. The evaluator's exit code is the verdict; the agent's self-report is ignored. The hierarchy, strongest first: `proof > type > property test > example test > linter`.
* **The adversarial path.** If no deterministic evaluator can exist, the condition is closed by adversarial review from **context-free agents operating out of decorrelated boundaries**. Decorrelation is load-bearing: a single reviewer shares the generator's attractor basin, so their blind spots coincide; context-free reviewers in different basins have non-overlapping blind spots whose union covers the artifact.

Both paths iterate to a fixed point against error feedback toward $\Delta E = 0$; if 3–5 corrective iterations fail to converge, the walk freezes and surfaces. The adversarial path also audits its own classification — "could this have been machine-checked?" — so the soft path self-polices back toward the hard path and never becomes an escape hatch. Human review is the escalation slot only.

The full ruleset lives in [rules.md](rules.md): six **Prime Invariants** in precedence order, the ambient boundary condition every walker inherits. The Dual is the first; the others are **Halt over assumption** (ambiguity freezes the walk — guessing is forbidden), **The Cutting Imperative** (below), **The history is the deliverable** (`git log` is the durable interface to human judgment), **Track state; reconstruct, don't recall**, and **Tier economy** (route every task to the cheapest walker whose capability bounds it).

---

### The Cutting Imperative and the maturity flag

Unjustified code, stale docs, and redundant skills are excess phase-space volume — drift surface. "Cut complexity" is the *same* invariant as "narrow the basin," applied to artifacts rather than tokens. A standing **maturity flag** sets the default stance:

* **`molten`** (pre-1.0) flips the default from "amend only" to *refactor and cut freely*.
* **`stable`** (post-1.0) restores amend-by-default, with cuts justified per change.

**This project's default is `molten`.** Treating a work-in-progress, mostly-machine-authored repository as a human-vetted immutable structure to be amended only is a defect, not caution.

---

### The control-theoretic substrate

The Dual rests on a control-theoretic model of generation. The math is still the foundation; it is the *substrate* beneath the doctrine, not the headline.

1. **Stochastic walks:** Token generation is a walk across a transition graph: $P(\mathbf{S}\_{t+1} \mid \mathbf{S}\_t)$, where the prefix sequence $\mathbf{S}\_t$ defines the state at step $t$.
2. **Entropy control:** Token selection uses the Gibbs-Boltzmann distribution:
   $$P(x\_i) = \frac{\exp(z\_i / \tau)}{\sum\_j \exp(z\_j / \tau)}$$
   where $z\_i$ represents the logits and $\tau$ is thermodynamic temperature. Lowering temperature collapses entropy, forcing deterministic local optimization.
3. **Closed-loop feedback:** An open-loop agent will eventually drift. Predicate closes the loop by running external, deterministic validators (compilers, linters, test runners). It captures the validator's output as an error differential ($\Delta E$) and injects corrective prompt feedback ($\Delta \mathbf{S}\_{k+1}$) to drive the system toward a zero-error state:
   $$\mathbf{S}\_{k+1} = \mathbf{S}\_k \oplus \Delta \mathbf{S}\_{k+1}$$

Predicate models the agent's prompt as an **Initial Boundary Condition (IBC)** that warps this probability landscape, carving a deep attractor basin to guide token selection. The Dual is the discipline that keeps the walk inside that basin: the symbolic path is the closed feedback loop made deterministic, and the adversarial path is the same loop run by decorrelated reviewers where no deterministic loop can exist.

---

### From math to code: the skill abstraction

Predicate translates this paradigm into concrete workspace configurations through modular **skills** loaded dynamically based on the active task:

* **Rules (phase-space constriction):** Declarative guardrails (like language styles) prune unneeded state-space dimensions. This lowers sequence entropy and prevents the model from wandering into invalid APIs.
* **Workflows (state-transition bounds):** State-machine SOPs (like `/core` or `/refine`) force the agent to generate intermediate step tokens (such as verification plans or audit logs). This induces a structured state-space expansion that lowers the conditional entropy of the final code.
* **Tools (error-differential feedback):** Executable validation scripts act as the outer-loop feedback controller. They run the validator, report the error vector, and loop until the validation error reaches zero.

---

### The verification protocol in practice

The Dual's symbolic path runs as a concrete local loop on every code change:

* **Test-driven invariants (TDD-first):** Before modifying any implementation code, the agent translates spec invariants into a test. The test must produce a baseline failure ($\Delta E\_0 \neq 0$) to verify that the validation boundary is active.
* **The local optimization loop:** During execution, the agent runs a local loop: edit the code, run the validator, capture the error differential ($\Delta E\_k$), and adjust. This loop repeats (up to 3–5 times) until the error converges to zero.
* **The Commit Gate:** Every commit — in the main repository, the `.sketches/` sub-repository, and every worktree — passes one gate. The message must pass the [commit-hygiene](skills/commit-hygiene/SKILL.md) validator; the staged surface must satisfy its [ledger contract](ledger/README.md) and be *authorized* (every staged path falls under some campaign node's declared `file_surface`); and the full test suite and linters must run. These checks are enforceable as git hooks (see [Enforcement](#enforcement-the-ledger-gates-and-hooks)), so a violation blocks the commit rather than relying on recall.

---

### Integration and standards

Predicate implements the [AGENTS.md specification](https://agents.md). Instead of inventing proprietary formats, it exposes rules, workflows, and tools inside the `.agents/` directory. Compliant coding platforms read this directory to discover and run local workspace skills.

---

### The ambient layer

A **skill** is an authority you invoke for a moment (`/core`, `/campaign`, `/refine`). Beneath the skills sits the **ambient layer** — standing principles that are never *not* active and so have no entrypoint to route to. They live in [ambient.md](ambient.md), presumed read alongside [rules.md](rules.md), and bind every walk whether or not a skill is invoked. When an ambient principle and an invoked skill speak to the same situation, the skill is the procedural authority for *how*; the ambient principle states the standing constraint on *whether and why*.

The ambient layer holds:

* **Planning invariants** — the Candor Obligation (challenge flawed premises directly; no hedging), Sketch Commit Discipline (every touch a commit), and Strategic Escalation (drift that violates an IBC's goal or non-goals halts the walk).
* **The sketch principle** — explore before you propose; alternatives are required; draft thinking stays draft. Exploration is a standing disposition, not a discrete step.
* **The dialectic principle** — thesis ⇄ adversarial antithesis → synthesis is the *shape* of the system. Its high-stakes tier switches the generating model itself, the strongest form of the Dual's decorrelation.
* **Boundary reconstruction** — drift is the default of open-loop generation, so a long walk periodically rebuilds its boundary from the durable sources rather than trusting accumulated context.
* **Code-edit constraints** — mandatory halt conditions, production-grade correctness rules, and the robust-testing mandate, binding whenever code is written.

Several of these were historically packaged as invokable skills only because past harnesses had no other place to put them; they belong in the substrate, not behind an entrypoint.

---

### The `boundary → campaign` spine

Predicate's coordination spine runs from contract to orchestration. Below it sit the single-walk execution workflows; above it sit the two tier-aware workflows that govern work across heterogeneous model classes.

The single-walk workflows separate concerns rather than phases of one pipeline — you use only what you need:

| Workflow | `/model` | `/core` | `/refine` |
| :--- | :--- | :--- | :--- |
| **Focus** | Formalize | Execute | Optimize |
| **Method** | Construct | Verify | Polish |
| **Output** | Commit model | Commit code | Commit refinement |

A well-scoped change goes straight to `/core`; `/model` can be invoked anywhere to formalize domain boundaries; `/refine` optimizes existing artifacts. Exploring before committing is the always-on ambient sketch principle, not a workflow.

The spine itself is two workflows:

* **`/boundary`** manufactures and adversarially refines the prompt contract (the IBC) before any expensive or autonomous walk launches. No expensive walk runs without a sufficient, human-approved boundary.
* **`/campaign`** lets an architect-class model frame the initiative, survey exhaustively, derive a mitigation plan as a dependency graph of worker tasks, emit one IBC per task routed to the cheapest capable tier, and judge the work that returns. Strategic framing and stress-test planning — what a standalone charter or plan once held — are produced and consumed inside `/campaign`'s ABSORB, SURVEY, and PLAN states in one architect pass.

The *what* of the execution layer is prose in the campaign skill; the *how* is specified deterministically in the machine-executable [orchestration protocol](docs/orchestration-protocol.md) — the exact procedure that drives a validated campaign DAG to a correctly merged branch, running identically whether a human, an agent, or an external tool drives it. Everything in it is deterministic-or-dispatched except a small set of explicitly marked **[HUMAN SEAM]** points (final acceptance and push, non-resolvable reserved halts, decision-rights realignment, and non-converging adversarial review).

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
2. **ATTACK:** Independent adversarial reviewers object by citing violated sufficiency conditions; contested framings escalate to the cross-model dialectic principle.
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

### Enforcement: the ledger, gates, and hooks

The Verification Dual's symbolic path is not a convention an agent is asked to remember — it is machinery. Three layers make it intrinsic:

* **The Nickel ledger ([ledger/](ledger/README.md)).** Every state artifact a campaign produces — its boundary, its DAG, its findings, its reconciliation record — is a [Nickel](https://nickel-lang.org) contract. The contracts make the artifacts' invariants *intrinsic*: a malformed artifact cannot be exported. `nix run nixpkgs#nickel -- export <file>.ncl` is the gate, with no out-of-band validation step a headless orchestrator could skip. The DAG contract enforces acyclicity, referential integrity, and that concurrent nodes declare disjoint file surfaces; the findings and reconcile-log contracts enforce one principle — *a condition is only closed once the evaluator that closes it is named.*
* **The gates ([gates/](gates/)).** Standalone evaluator scripts that close conditions `check_docs` cannot: `check_orphans.sh` is the referential-truth gate (a reference that *names* a removed or demoted workflow as if it were live fails it), and `check_selfcontained.sh` rejects commit messages with references a stranger reading `git log` could not resolve.
* **The git hooks ([hooks/](hooks/)).** `hooks/install-hooks.sh` wires a `commit-msg` hook (Conventional Commits form plus self-containment) and a `pre-commit` hook (staged markdown links valid, staged Nickel artifact satisfies its contract, no staged file references a removed workflow as live). The installer is worktree-aware, so one install covers the main checkout and every linked worktree. A violation *blocks* the commit — the Commit Gate enforced as a gate, not a memory.

---

### The sketch as a lifecycle journal

Exploration before commitment is the always-on **sketch principle** (an ambient layer principle, above). Its durable **substrate** is the `.sketches/` flight recorder — a git-tracked record that lets any walk reconstruct full context from a single subtree. The principle and the substrate are distinct: the disposition is ambient, the flight recorder is load-bearing infrastructure.

The sketch is not discarded when implementation begins; it serves as a living record across all workflows:

| Workflow | Sketch Role |
| :--- | :--- |
| `/model` | Domain formalizations and mathematical maps |
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
