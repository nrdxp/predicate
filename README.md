# Predicate

Modular rules, skills, and workflows that keep AI coding assistants anchored to the true goal across long-horizon work.

Predicate is built from two synergistic halves: **correction** relaxes drift back out in an outer loop once it appears, and **prevention** keeps the walk focused *before* drift compounds. Correction without prevention corrects toward the wrong goal; prevention without correction drifts anyway over a long horizon. Together they bound drift.

See the [Getting Started Guide](docs/getting-started.md) to integrate Predicate into your project.

## Repository structure

```
predicate/
├── rules.md     # The master ruleset: the Verification Dual and the Prime Invariants every walker inherits
├── ambient.md   # Always-on principles that are not workflows (no entrypoint)
├── skills/      # Encapsulated agent skills (rules, workflows, tools)
├── ledger/      # Nickel contracts that make campaign artifacts machine-valid
├── gates/       # Standalone evaluator scripts (orphan, self-containment)
├── hooks/       # Git hooks that enforce the Commit Gate at commit time
├── templates/   # Project templates (IBC.md, ADR.md, etc.)
└── docs/        # Guides, the orchestration protocol, ADRs, and theory
```

Two directories are runtime-only and gitignored by the parent repository: `.scratch/`
holds a campaign's ephemeral working set, and `.ledger/` is the durable history
sub-repository (the flight recorder). Neither is tracked here; see
[the flight recorder](#the-flight-recorder) below.

### Terminology

Predicate packages all agent assets as **skills**:

| Term | Category | Description |
| :--- | :--- | :--- |
| **Rule** | Constraint | Declarative guardrails (like `rust` or `engineering` guidelines). |
| **Workflow** | Procedure | State-machine SOPs (like `core`, `refine`, or `campaign`). |
| **Tool** | Capability | Executable scripts (like `security-audit`). |

---

## Architecture: correction + prevention

Prompt engineering is a fragile way to program. Autoregressive language models do not "think" or "reason"; they execute a stochastic walk across a discrete token state-space. Over long generations, errors compound, and the boundary condition that set the agent on course fades as context accumulates. Without external structure, an agent will eventually drift off course, write unverified code, or introduce regressions.

A drifting walk fails in two distinct ways, so Predicate answers each with its own half:

* **Correction** detects drift *after* it appears and relaxes it back out — an outer feedback loop scored by the strongest available evaluator. This is the **Verification Dual**.
* **Prevention** keeps the walk in its basin *before* drift compounds — externalizing the goal, requirements, unknowns, and available tools as a durable, selectively re-surfaced **conditioning layer**.

The two are not ranked; they are peers that cover different failure modes. Correction relaxes error away from a fixed attractor; prevention keeps that attractor felt as the context grows. The intro to [rules.md](rules.md) and the project goal in [AGENTS.md](AGENTS.md) state the same architecture; the halves below expand each at the level of a newcomer.

---

### The correction half: the Verification Dual

Predicate's core invariant is the **Verification Dual: verify, then trust.** No condition is ever closed by an agent's say-so. Every condition that must hold is closed by the strongest applicable evaluator, and exactly one of two complementary paths closes it:

* **The symbolic path.** If a deterministic evaluator exists or can be built — a proof, a type, a property test, an example test, a linter — it *must* be used. The evaluator's exit code is the verdict; the agent's self-report is ignored. The hierarchy, strongest first: `proof > type > property test > example test > linter`.
* **The adversarial path.** If no deterministic evaluator can exist, the condition is closed by adversarial review from **context-free agents operating out of decorrelated boundaries**. Decorrelation is load-bearing: a single reviewer shares the generator's attractor basin, so their blind spots coincide; context-free reviewers in different basins have non-overlapping blind spots whose union covers the artifact.

Both paths iterate to a fixed point against error feedback toward $\Delta E = 0$; if 3–5 corrective iterations fail to converge, the walk freezes and surfaces. The adversarial path also audits its own classification — "could this have been machine-checked?" — so the soft path self-polices back toward the hard path and never becomes an escape hatch. Human review is the escalation slot only.

The full ruleset lives in [rules.md](rules.md): six **Prime Invariants** in precedence order, the ambient boundary condition every walker inherits. The Dual is the first; the others are **Halt over assumption** (ambiguity freezes the walk — guessing is forbidden), **The Cutting Imperative** (below), **The history is the deliverable** (`git log` is the durable interface to human judgment), **Track state; reconstruct, don't recall**, and **Tier economy** (route every task to the cheapest walker whose capability bounds it).

#### The Cutting Imperative and the maturity flag

Unjustified code, stale docs, and redundant skills are excess phase-space volume — drift surface. "Cut complexity" is the *same* invariant as "narrow the basin," applied to artifacts rather than tokens. A standing **maturity flag** sets the default stance:

* **`molten`** (pre-1.0) flips the default from "amend only" to *refactor and cut freely*.
* **`stable`** (post-1.0) restores amend-by-default, with cuts justified per change.

**This project's default is `molten`.** Treating a work-in-progress, mostly-machine-authored repository as a human-vetted immutable structure to be amended only is a defect, not caution.

---

### The prevention half: the conditioning layer

Correction assumes the walk still knows what it is correcting *toward*. That assumption decays. The attractor basin an agent's prompt carves at $t=0$ does not hold its grip: self-attention spreads a fixed probability mass across an ever-growing context, so the mutual information between the original goal and the next token is non-increasing as the prefix lengthens. The goal does not stay felt on its own — it has to be re-supplied. Prevention is the discipline of keeping it felt.

The mechanism is a **conditioning layer**: the goal, requirements, unknowns, and available tools are externalized into durable carriers and projected back into the walk *selectively* — only the highest-precedence, currently-relevant subset, because re-injecting everything would re-dilute the very mass it means to concentrate. Three failure modes the conditioning layer guards against, each a force the boundary prompt alone does not contain:

* **The basin's hold decays with length.** The restoring operator is **selective re-surfacing** — placing the load-bearing invariant back into the recent context to re-deepen the basin at the current step. This is the [boundary-reconstruction reflex](ambient.md#boundary-reconstruction) that [rules.md](rules.md) §7 mandates at the start of every long-horizon step: reload the governing invariants and the active ledger rather than trusting accumulated context.
* **The design space narrows as constraints are discovered.** Each surfaced constraint is an irreversible cut to the set of valid designs, exactly as each emitted token cuts the set of valid trajectories. The same `molten`/`stable` maturity flag the Cutting Imperative declares is, from this angle, a reading of that contraction's *rate*: high rate (still discovering constraints) means `molten`; the rate going dry means `stable` — a measured curve, not a date.
* **A locally-optimal move can defeat a parent goal.** Goals are nested basins — task ⊂ component ⊂ project ⊂ ecosystem. A move can satisfy the innermost constraint while exiting an outer one (a green test bought by weakening the property; an expedient hack). That is a **defeater**, and the trigger for **Strategic Escalation**: tactical drift stays inside the parent basin and is recorded; strategic drift exits it and halts the walk.

These three are derived in the same phase-space language as the correction half in [the formalism](docs/theory/formalism.md) (Part 2); the standing principles they ground live in [ambient.md](ambient.md). The discipline rests on a few concrete pieces a newcomer should know:

* **The carrier stack.** Knowns and known-unknowns ride one stack of carriers, never duplicated docs. The project's **`AGENTS.md` is the persistent goal-anchor** — a nested hierarchy (ecosystem ⊃ project ⊃ component) holding the goal, requirements, invariants, and the structural map; [this repository's own AGENTS.md](AGENTS.md) is the first instance. A live Nickel context-map projects the *active* subset per surface with freshness and signpost markers; the [flight recorder](#the-flight-recorder) is the narrative history; `.scratch` is the volatile draft that syncs into the anchor only at reconciliation boundaries.
* **Epistemic discipline — the four quadrants.** A walk maps what it knows about its goal before committing: *knowns* (pruned to the minimal set that still bounds the goal — requirement bloat is its own drift surface), *known-unknowns* (tracked first-class like requirements, each with a **signpost**: the observable that would resolve it), and *unknown-unknowns* (surfacing one is high-value signal — file it with a signpost rather than suppress or chase it). The rate of new discovery is the measured reading behind the maturity flag above.
* **The focus-level selector.** The first question of any boundary is not *what* but *how much ceremony*. Over-ceremony drifts as surely as under-ceremony — running a campaign's survey-and-orchestrate machinery on a leaf edit dilutes the attention it means to focus. Match the discipline to the task before drawing the boundary.
* **Bidirectional outward search.** Before halting on a gap, a walk looks outward along two axes: *toward the world* (prior art, RFCs, literature) to map the domain, and *toward the environment* (the harness's installed skills, tools, and MCP servers — the arsenal) to map capability. Reaching for the habitual tool without surveying the arsenal is hole-digging in capability space.

A project enters this layer through the [`/orient`](skills/orient/SKILL.md) workflow, which maps a repository and authors its `AGENTS.md` hierarchy so every subsequent walk is anchored and gated. The prevention half is in active design (`WIP`); see [AGENTS.md](AGENTS.md) for what has landed and what is still being built.

---

### The machinery beneath the halves

Both halves rest on shared substrate — the standing principles every walk inherits, the coordination spine that routes work, the enforcement that makes the Dual intrinsic, the flight recorder that makes history durable, and the control-theoretic model both halves are derived in.

#### The ambient layer

A **skill** is an authority you invoke for a moment (`/core`, `/campaign`, `/refine`). Beneath the skills sits the **ambient layer** — standing principles that are never *not* active and so have no entrypoint to route to. They live in [ambient.md](ambient.md), presumed read alongside [rules.md](rules.md), and bind every walk whether or not a skill is invoked. When an ambient principle and an invoked skill speak to the same situation, the skill is the procedural authority for *how*; the ambient principle states the standing constraint on *whether and why*.

The ambient layer holds:

* **Planning invariants** — the Candor Obligation (challenge flawed premises directly; no hedging), Sketch Commit Discipline (every touch a commit), and Strategic Escalation (drift that violates an IBC's goal or non-goals halts the walk).
* **The sketch principle** — explore before you propose; alternatives are required; draft thinking stays draft. Exploration is a standing disposition, not a discrete step.
* **The dialectic principle** — thesis ⇄ adversarial antithesis → synthesis is the *shape* of the system. Its high-stakes tier switches the generating model itself, the strongest form of the Dual's decorrelation.
* **Boundary reconstruction** — drift is the default of open-loop generation, so a long walk periodically rebuilds its boundary from the durable sources rather than trusting accumulated context.
* **The Outward-Search Reflex** — before halting on a missing fact or pattern, run a bounded outward search (prior art, RFCs, literature); halting with a question you could have answered by looking is the same defect class as guessing.
* **Code-edit constraints** — mandatory halt conditions, production-grade correctness rules, and the robust-testing mandate, binding whenever code is written.

Several of these were historically packaged as invokable skills only because past harnesses had no other place to put them; they belong in the substrate, not behind an entrypoint.

---

#### The `boundary → campaign` spine

Predicate's coordination spine runs from contract to orchestration. Below it sit the single-walk execution workflows; above it sit the two tier-aware workflows that govern work across heterogeneous model classes.

The single-walk workflows separate concerns rather than phases of one pipeline — you use only what you need. Each is invoked by moment, runs as a strict state machine, and closes at the Commit Gate:

| Workflow | Focus | Entrypoint | Essence |
| :--- | :--- | :--- | :--- |
| Formalize a domain | Build or apply a mathematical model | [`/form`](skills/form/SKILL.md) | Select the simplest math that captures the domain; halt for approval before building. |
| Execute plan steps | Drive granular changes to commit | [`/core`](skills/core/SKILL.md) | TDD state machine (Absorb → Clarify → Plan → Execute) with review blocks at each boundary. |
| Optimize existing artifacts | Audit and polish in place | [`/refine`](skills/refine/SKILL.md) | Contraction loop with multi-sweep adversarial review until findings reach zero. |
| Write or audit documentation | Structured documentation lifecycle | [`/doc`](skills/doc/SKILL.md) | Audit → Plan → Draft → Review → Verify against the Divio quadrants. |
| Maintain project history | Incremental chronicle updates | [`/chronicle`](skills/chronicle/SKILL.md) | Summarize commit batches between SHA cutoffs into `docs/chronicle.md`. |

A well-scoped change goes straight to `/core`; `/form` can be invoked anywhere to formalize domain boundaries; `/refine` optimizes existing artifacts. Exploring before committing is the always-on ambient sketch principle, not a workflow.

The spine itself is the two tier-aware workflows:

* **`/boundary`** manufactures and adversarially refines the prompt contract (the Initial Boundary Condition, or IBC) before any expensive or autonomous walk launches. Seven sufficiency conditions (S1–S7) govern every IBC — falsifiable premises, a first-class rejection genre, resolved/delegated/reserved decision rights, evaluator attachment, curated context, load-bearing vs plastic amendment rights, and boundary mass scaled to walker capability. A good boundary is optimized for *cheap rejection*: the receiving model must be able to refute a wrong frame in its first few hundred tokens. No expensive walk runs without a sufficient, human-approved boundary.
* **`/campaign`** lets an architect-class model frame the initiative, survey exhaustively, derive a mitigation plan as a dependency graph of worker tasks, emit one IBC per task routed to the cheapest capable tier, and judge the work that returns. Strategic framing and stress-test planning — what a standalone charter or plan once held — are produced and consumed inside `/campaign`'s ABSORB, SURVEY, and PLAN states in one architect pass. After each dispatch it reconciles: re-running evaluators on landed work and re-verifying every pending prompt's premises against current `HEAD` before dispatching further.

The *what* of the execution layer is prose in the campaign skill; the *how* is specified deterministically in the machine-executable [orchestration protocol](docs/orchestration-protocol.md) — the exact procedure that drives a validated campaign DAG to a correctly merged branch, running identically whether a human, an agent, or an external tool drives it. Everything in it is deterministic-or-dispatched except a small set of explicitly marked **[HUMAN SEAM]** points (final acceptance and push, non-resolvable reserved halts, decision-rights realignment, and non-converging adversarial review).

---

#### Enforcement: the ledger, gates, and hooks

The Verification Dual's symbolic path is not a convention an agent is asked to remember — it is machinery. Three layers make it intrinsic:

* **The Nickel ledger ([ledger/](ledger/README.md)).** Every state artifact a campaign produces — its boundary, its DAG, its findings, its reconciliation record — is a [Nickel](https://nickel-lang.org) contract. The contracts make the artifacts' invariants *intrinsic*: a malformed artifact cannot be exported. The DAG contract enforces acyclicity, referential integrity, and that concurrent nodes declare disjoint file surfaces; the findings and reconcile-log contracts enforce one principle — *a condition is only closed once the evaluator that closes it is named.*
* **The gates ([gates/](gates/)).** Standalone evaluator scripts that close conditions a generic doc check cannot: `check_orphans.sh` is the referential-truth gate (a reference that *names* a removed or demoted workflow as if it were live fails it), and `check_selfcontained.sh` rejects commit messages with references a stranger reading `git log` could not resolve.
* **The git hooks ([hooks/](hooks/)).** `hooks/install-hooks.sh` wires a `commit-msg` hook (Conventional Commits form plus self-containment) and a `pre-commit` hook (staged markdown links valid, staged Nickel artifact satisfies its contract, no staged file references a removed workflow as live). The installer is worktree-aware, so one install covers the main checkout and every linked worktree. A violation *blocks* the commit — the Commit Gate enforced as a gate, not a memory.

The Commit Gate runs in every repository, including the independent `.ledger/` sub-repository and every worktree. The message must pass the [commit-hygiene](skills/commit-hygiene/SKILL.md) validator. The staged surface is then checked in two layers with different activation (see [rules.md](rules.md) §3): the **structural layer** always runs — staged markdown links must be valid, staged Nickel artifacts must satisfy their contracts, and no staged file may orphan a removed workflow; the **authority layer** runs only when a campaign is in flight, signalled by the `.ledger/active-dag` pointer — when that pointer is present, every staged path must fall under some campaign node's declared `file_surface`. An ordinary commit with no pointer gets the structural layer alone. The full test suite and linters must also run.

---

#### The flight recorder

Exploration before commitment is the always-on **sketch principle** (an ambient layer principle, above). Its durable substrate is the **flight recorder** at `.ledger/log/`. The principle and the substrate are distinct: the disposition is ambient, the recorder is load-bearing infrastructure.

The topology has two runtime directories, both gitignored by the parent repository so it never tracks transient or subrepo state:

* **`.scratch/`** — a campaign's ephemeral working set (live review, plan, orchestration, and prompts). Mutable and never committed.
* **`.ledger/`** — an independent sub-repository with its own git history. Its `.ledger/log/` subtree is the flight recorder: a committed, linear record of every architectural decision, discovery, and pivot, checkpointed at each reconciliation boundary. Because the parent ignores `.ledger/` but the subrepo commits internally, the record is durable *within the subrepo* without polluting the parent's history — and any campaign can be regenerated from the recorder plus `git`.

Every modification is committed to the flight recorder immediately (Sketch Commit Discipline). This creates a linear history that lets any walk reconstruct full context from a single subtree. It serves as a living record across all workflows: domain maps under `/form`, execution notes under `/core`, sweep traces under `/refine`, sufficiency objections under `/boundary`, and reconcile checkpoints under `/campaign`.

---

#### The control-theoretic substrate

Both halves rest on one control-theoretic model of generation. The math is the *substrate* beneath the doctrine, not the headline.

1. **Stochastic walks:** Token generation is a walk across a transition graph: $P(\mathbf{S}\_{t+1} \mid \mathbf{S}\_t)$, where the prefix sequence $\mathbf{S}\_t$ defines the state at step $t$.
2. **Entropy control:** Token selection uses the Gibbs-Boltzmann distribution:
   $$P(x\_i) = \frac{\exp(z\_i / \tau)}{\sum\_j \exp(z\_j / \tau)}$$
   where $z\_i$ represents the logits and $\tau$ is thermodynamic temperature. Lowering temperature collapses entropy, forcing deterministic local optimization.
3. **Closed-loop feedback:** An open-loop agent will eventually drift. Predicate closes the loop by running external, deterministic validators (compilers, linters, test runners). It captures the validator's output as an error differential ($\Delta E$) and injects corrective prompt feedback ($\Delta \mathbf{S}\_{k+1}$) to drive the system toward a zero-error state:
   $$\mathbf{S}\_{k+1} = \mathbf{S}\_k \oplus \Delta \mathbf{S}\_{k+1}$$

Predicate models the agent's prompt as an **Initial Boundary Condition (IBC)** that warps this probability landscape, carving a deep attractor basin to guide token selection. This grounds **both** halves in one model. Correction is the outer loop: the symbolic path is the closed feedback loop made deterministic, and the adversarial path is the same loop run by decorrelated reviewers where no deterministic loop can exist. Prevention is the same phase-space operators lifted onto phenomena the four core mappings leave implicit — the basin's hold decaying with context length, the design space contracting per discovered constraint, and goals nesting as containment so a local move can defeat a parent. The prevention half above states these at the level of practice; [the formalism](docs/theory/formalism.md) Part 2 derives them.

The full first-principles derivation — the Markov-chain assumption, the Boltzmann engine, phase-space constriction, closed-loop control, and the prevention-half extension — lives in [docs/theory/formalism.md](docs/theory/formalism.md).

---

## Getting started

See the [Getting Started Guide](docs/getting-started.md) for setup instructions.

---

## Contributing

Predicate is designed to be forked and customized. You can easily add organization-specific rules, workflows, or custom validators. See [docs/authoring.md](docs/authoring.md) to write your own skills.

## License

MIT
