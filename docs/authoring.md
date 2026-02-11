# Writing Custom Axioms, Personas, and Workflows

How to extend predicate with your own rulesets, context extensions, and task procedures.

**Audience:** Contributors to predicate or developers forking it for custom rulesets.

---

## The Three Tiers

Each tier has a different activation model. This determines what belongs where.

| Tier         | When Active                                         | Voice                                     |
| :----------- | :-------------------------------------------------- | :---------------------------------------- |
| **Axiom**    | Always — loaded unconditionally on every task       | Authoritative. Non-negotiable rules.      |
| **Persona**  | On demand — required by project or adopted by agent | Advisory. Domain-specific best practices. |
| **Workflow** | On trigger — user invokes via slash command         | Procedural. Step-by-step protocol.        |

**The activation model is the key design decision.** If a rule must apply to every task regardless of context, it's an axiom. If it applies only to certain languages, domains, or tools, it's a persona. If it's a structured procedure the user triggers deliberately, it's a workflow.

---

## Axioms

Axioms live in `axioms/`. The agent reads and obeys every axiom on every task — no opt-out. This means axioms must be:

- **Universal** — applicable to any project, any language, any task type
- **Concise** — every line costs context on every interaction; earn your bytes
- **Non-conflicting** — axioms cannot contradict each other

### Frontmatter

```yaml
---
name: "Human-Readable Name"
description: "One-line purpose"
version: "1.0.0" # optional, but useful for tracking changes
---
```

### Writing Guidelines

1. **Use imperative voice.** Axioms are rules, not suggestions. "Validate external inputs at system boundaries" — not "Consider validating inputs."
2. **Include anti-patterns.** Concrete examples of forbidden behavior are more effective than abstract principles. Use the `❌`/`✅` pattern established in `engineering.md`.
3. **Define precedence.** If your axiom interacts with existing ones, state the priority explicitly (e.g., `engineering.md > documentation.md > other personas`).
4. **Keep it under 300 lines.** An axiom longer than `engineering.md` (~277 lines) is likely trying to do too much. Consider splitting domain-specific content into a persona.

### When NOT to Write an Axiom

- If the rule applies only to one language → **persona**
- If the rule applies only during a specific task type → **workflow** or **persona**
- If the rule is a procedure with multiple states → **workflow**

---

## Personas

Personas live in `personas/`. They're loaded when a project marks them active in `AGENTS.md`, when a workflow declares them in `required_personas:`, or when the agent discretionarily adopts one based on task relevance.

### Frontmatter

```yaml
---
name: "Persona Name"
description: "One-line purpose"
---
```

### Writing Guidelines

1. **Be specific to a domain.** Language idioms, tool usage patterns, framework conventions — a persona should represent expertise the agent needs only in certain contexts.
2. **Complement, don't repeat.** Personas extend axioms. Don't restate rules from `engineering.md` — reference them and add domain-specific detail.
3. **Use the established pattern.** Study `go.md`, `rust.md`, or `typescript.md` for the expected depth and structure: idioms, naming conventions, error handling patterns, testing conventions, and anti-patterns.
4. **Declare integration.** State how the persona relates to axioms and other personas. Example from `integral.md`: "This predicate augments, not overrides, `engineering.md`."

### Activation Modes

A persona can be activated three ways:

- **Project-required:** Listed in `AGENTS.md` under `Active Personas:` — loaded for every task in that project
- **Workflow-required:** Listed in a workflow's `required_personas:` frontmatter — loaded when that workflow triggers
- **Discretionary:** The agent detects domain relevance and adopts it, announcing the choice

---

## Workflows

Workflows live in `workflows/`. They're triggered via slash commands (`/plan`, `/core`, `/doc`, etc.) and define structured procedures with explicit states, transitions, and halt points.

### Frontmatter

```yaml
---
name: "workflow-name"
description: "One-line purpose"
trigger: "/slash-command"
required_personas:
  - planning # optional: personas loaded when this workflow activates
---
```

### Writing Guidelines

1. **Define a state machine.** Workflows should have explicit states, valid transitions, and clear definitions of what happens in each state. Use ASCII diagrams for the transition graph.
2. **Declare halt points.** Every workflow must specify where the agent MUST stop and await human input. Unclear halt semantics lead to runaway execution.
3. **Include a YAML grammar.** Define the structured state the agent maintains during execution. This keeps the agent's context explicit and inspectable. See `core.md` or `plan.md` for examples.
4. **List protocol violations.** A table of forbidden behaviors, with explanations of why they're wrong, prevents the most common failure modes. Every mature workflow should have one.
5. **Keep the slash command short.** One word, lowercase, memorable. Consistent with existing patterns: `/sketch`, `/plan`, `/core`, `/doc`.

### Anatomy of a Workflow

Most workflows follow this structure:

```markdown
# Protocol Name

Philosophy / purpose statement

## Scope — when to use (and when not to)

## Grammar — YAML state definition

## State Transitions — ASCII diagram + definitions

## Prime Directives — numbered, enforceable rules

## Protocol Violations — forbidden behavior table

## MANDATORY HALT Points — where the agent must stop

## Response Format — what output looks like in each state
```

### The `required_personas` Field

Workflows can require specific personas to ensure the agent has domain context. When a workflow with `required_personas` is triggered, the agent loads those personas before execution begins. If a required persona file is missing, the agent HALTs and asks the human.

---

## General Principles

These apply across all three tiers:

1. **Frontmatter is mandatory.** Every file in `axioms/`, `personas/`, and `workflows/` must have YAML frontmatter with at least `name` and `description`.
2. **Use GitHub Flavored Markdown.** Tables, alert blocks (`> [!IMPORTANT]`, `> [!CAUTION]`), and fenced code blocks.
3. **Anti-patterns over platitudes.** "Don't do X because Y" teaches more than "strive for quality." Concrete forbidden behaviors, with explanations, are the most effective form of guidance.
4. **Test with an agent.** The best way to validate a new axiom, persona, or workflow is to use it. If the agent misinterprets a rule, the rule is unclear — fix the rule, not the agent.
