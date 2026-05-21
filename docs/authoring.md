# Writing Custom Rules, Skills, and Workflows

How to extend predicate with your own rulesets, custom capabilities, and task procedures.

**Audience:** Contributors to predicate or developers forking it for custom configurations.

---

## The Core Concepts: Rules, Skills, and Workflows

Predicate is structured around three primary categories of configuration:

1. **Rules** (located in `rules/`): General guidelines, constraints, and schemas that govern how the agent behaves and reasons. They are activated automatically based on frontmatter configuration.
2. **Skills** (located in `skills/`): Composed capabilities (encapsulated guidelines, scripts, or assets) loaded semantically when a specific capability is required.
3. **Workflows** (located in `workflows/`): Manual procedures and protocols triggered by the user via slash commands (e.g., `/plan`, `/core`, `/doc`).

---

## Rules

Rules live in `rules/` and consolidate the legacy concepts of *axioms* and *personas*. A rule's activation model is defined by its frontmatter.

### The Three Rule Types

| Type | Frontmatter Activation | When Active | Purpose / Voice |
| :--- | :--- | :--- | :--- |
| **Axiom** | `activation: always` | Active unconditionally on every task | Universal, non-negotiable standards (e.g., code safety). |
| **Glob Rule** | `activation: glob` | Active when editing or reading matched files | Language-specific or filetype conventions (e.g., `*.go` patterns). |
| **Model Rule** | `activation: model` | Activated semantically by the model when relevant | Domain-specific guidance (e.g., domain modeling). |

---

### Axioms (`activation: always`)

Axioms must be universal, concise, and non-conflicting. Because they load on every single interaction, every byte should earn its place in the context window.

#### Frontmatter
```yaml
---
name: "engineering"
description: "Technical and maintainability rules for codebase edits"
activation: always
---
```

#### Guidelines
1. **Use imperative voice.** Axioms are rules, not recommendations. "Validate external inputs at system boundaries" — not "Consider validating inputs."
2. **Include anti-patterns.** Concrete examples of forbidden behavior are highly effective. Use the `❌`/`✅` pattern established in `engineering.md`.
3. **Keep it under 300 lines.** Axioms should stay high-level and universal. If a rule only applies to Go or Rust, move it to a glob rule.

---

### Glob Rules (`activation: glob`)

Glob rules are automatically injected into the agent's context when working with specific file paths or extensions. This prevents loading irrelevant context (e.g., loading Rust guidelines on a Python codebase).

#### Frontmatter
```yaml
---
name: "rust"
description: "Idiomatic programming style and practices for Rust"
activation: glob
pattern: "**/*.rs"
---
```

#### Guidelines
1. **Focus on language idioms.** Cover naming conventions, error handling protocols, performance best practices, testing conventions, and common anti-patterns for the matched language or tool.
2. **Define patterns precisely.** Use standard glob syntax in the `pattern` property (e.g., `**/*.ts` or `**/*.qmd`).

---

### Model Rules (`activation: model`)

Model rules (personas) are loaded semantically. The agent's platform indexes the rule's `description` frontmatter field and injects the rule when the task description matches keywords or concepts.

#### Frontmatter
```yaml
---
name: "sdma"
description: "Trigger when designing domain models, building ologs, verifying protocol equivalence, selecting schemas, or measuring architectural entropy."
activation: model
---
```

#### Guidelines
1. **Provide high-density descriptions.** Use explicit, keyword-rich descriptions to facilitate accurate semantic search triggers.
2. **Complement, don't repeat.** Do not restate rules from global axioms; instead, provide domain-specific context.

---

## Skills

Skills live in subdirectories under `skills/` (e.g., `skills/depmap/`). Each skill acts as a modular capability containing instructions, references, and optional execution scripts. Unlike workflows, which prescribe step-by-step procedures, skills act as functional toolkits that the agent invokes dynamically.

### Frontmatter

Every skill must define a `SKILL.md` file at its root containing YAML frontmatter:

```yaml
---
name: skill-name
description: "Detailed semantic description specifying when to trigger this capability."
---
```

### Directory Structure

A typical skill directory contains:

```
skills/my-custom-skill/
├── SKILL.md            # Required: Skill definition and guidelines
├── scripts/            # Optional: Execution scripts (Python, Bash, etc.)
└── resources/          # Optional: Templates, reference files, or static assets
```

### Guidelines

1. **Semantic Descriptions**: Use high-density, search-optimized keyword phrases in the frontmatter `description` field. The runner indexes this description to match and inject the skill when the user's prompt or the agent's task warrants it.
2. **Context-Specific Instructions**: Use the `SKILL.md` body to detail precisely *how* the agent should utilize the skill's tools, scripts, or references. Delineate concrete scenarios and edge cases.
3. **Execution Scripts**: Put helper scripts inside a `scripts/` subdirectory. Document their arguments, expected inputs/outputs, and prerequisite environments clearly within the `SKILL.md`.

---

## Workflows

Workflows live in `workflows/`. They are triggered by the user via slash commands (like `/plan` or `/core`) and define structured, step-by-step procedures.

### Frontmatter

```yaml
---
name: "workflow-name"
description: "One-line purpose"
trigger: "/slash-command"
required_personas:
  - planning # optional: names of model rules loaded when this workflow activates
---
```

### Guidelines

1. **Define a state machine.** Workflows should have explicit states, valid transitions, and clear definitions of what happens in each state. Use ASCII diagrams for the transition graph.
2. **Declare halt points.** Every workflow must specify where the agent MUST stop and await human input (e.g., at commit boundaries or design approvals).
3. **Include a YAML grammar.** Define the structured state the agent maintains during execution. This keeps the agent's context explicit and inspectable. See `core.md` or `plan.md` for examples.
4. **List protocol violations.** Include a table of forbidden behaviors to prevent common failure modes.
5. **Keep the slash command short.** One word, lowercase, memorable. Consistent with existing patterns: `/sketch`, `/plan`, `/core`, `/doc`.

---

## General Principles

These apply across all rules, skills, and workflows:

1. **Frontmatter is mandatory.** Every configuration file in `rules/`, `workflows/`, and `skills/` (specifically `SKILL.md` files) must contain valid YAML frontmatter with `name` and `description`, along with `activation` (for rules) or `trigger` (for workflows).
2. **Use GitHub Flavored Markdown.** Structure text with tables, bullet lists, alert blocks (`> [!IMPORTANT]`, `> [!CAUTION]`), and syntax-highlighted code blocks.
3. **Anti-patterns over platitudes.** "Don't do X because Y" is far more effective than vague requests like "strive for quality."
4. **Link references correctly.** Link between files using GitHub markdown links with relative paths or absolute file scheme links (e.g. `[constitution.md](file:///absolute/path/to/rules/constitution.md)`).
