# Writing Custom Agent Skills

How to extend Predicate with your own modular agent skills (rulesets, procedures, and capabilities).

**Audience:** Contributors to Predicate or developers forking it for custom configurations.

---

## The Unified Skills Architecture

Predicate consolidates all agent configuration under the **Skills** abstraction. A skill resides in a subdirectory of `skills/` (e.g., `skills/my-skill/`) and must contain a `SKILL.md` entry point. 

Skills are categorized by their role, but share the same directory structure and loading model:

1. **Rule Skills:** Declarative constraints, language idioms, and architectural guardrails (e.g., `rust`, `engineering`).
2. **Workflow Skills:** Procedural SOPs with structured states, state machines, and checkpoints (e.g., `refine`, `core`).
3. **Tool Skills:** Functional capabilities containing executable scripts or dependency maps (e.g., `depmap`, `security-audit`).

---

## Directory Structure

A skill directory is structured as:

```
skills/my-custom-skill/
├── SKILL.md            # Required: Skill definition, triggering description, and guidelines
├── scripts/            # Optional: Automation / execution scripts (Python, Bash, etc.)
└── resources/          # Optional: Templates, reference files, or static assets
```

---

## Frontmatter Triggering Strategy

Because skills are loaded semantically by agent runners (such as `agy` and Claude Code) based on the user's prompt or task description, the YAML frontmatter `description` of `SKILL.md` is critical. 

Always use YAML multi-line block scalars (`|`) to define highly descriptive semantic keyword triggers, specifying relevant tasks, file suffixes, and command triggers.

### 1. Authoring Rule Skills

Rule skills provide passive constraints. Delineate clear style requirements, error handling guidelines, and anti-patterns.

#### Example Frontmatter:
```yaml
---
name: rust
description: |
  Idiomatic programming style, patterns, and conventions for Rust development.
  Trigger when:
  - Writing, refactoring, reviewing, or debugging Rust code.
  - Files matching the pattern **/*.rs (including Cargo.toml, Cargo.lock) are in the workspace or referenced.
  - Tasks involve: cargo build, cargo clippy, cargo test, cargo check, rustc.
  - Prompt contains keywords: rust, cargo, clippy, borrow checker, lifetime, struct, enum, impl, Option, Result, match, unwrap, unsafe.
---
```

#### Guidelines:
1. **Focus on idioms and constraints:** Define language-specific conventions, error handling protocols, and safety practices.
2. **Use imperative voice:** Rules must be clear and direct. "Validate input at borders" rather than "Consider input validation."
3. **Include anti-patterns:** Use the `❌`/`✅` code pattern to illustrate correct vs. incorrect practices clearly.

---

### 2. Authoring Workflow Skills

Workflow skills define active SOP procedures. They guide the agent through structured phases.

#### Example Frontmatter:
```yaml
---
name: core
description: |
  SOP for the micro-execution C.O.R.E. phase.
  Trigger when:
  - Implementing plan steps, managing code changes at commit boundaries, and verifying incremental progress.
  - Navigating states: Absorb, Clarify, Plan, Execute.
  - Prompt contains: /core, core workflow, absorb, clarify, execution invariants, commit boundary, verify assertion.
---
```

#### Guidelines:
1. **Define a state machine:** Workflows must detail explicit states, valid transitions, and what happens in each state. Provide an ASCII transition diagram.
2. **Declare halt points:** Specify where the agent MUST stop execution to await human approval.
3. **Include a YAML grammar:** Define a structured state object that the agent must maintain to keep its context explicit and inspectable.
4. **List protocol violations:** Provide a table of forbidden behaviors to keep the agent aligned with the workflow.

---

### 3. Authoring Tool Skills

Tool skills package custom utilities or external integration instructions with executable helper scripts.

#### Example Frontmatter:
```yaml
---
name: depmap
description: |
  Repository and dependency analysis tools.
  Trigger when:
  - Exploring new/large codebases, mapping API surfaces, or finding type/function definitions.
  - Prompt contains keywords: repo_map, search_identifiers, resolve_dependencies, dep_map.
---
```

#### Guidelines:
1. **Document script arguments:** Clearly document how to run any scripts inside the `scripts/` directory, including their inputs, outputs, and requirements.
2. **Handle errors gracefully:** Provide instructions on what the agent should do if an external tool or script execution fails.

---

## General Principles

1. **Frontmatter is mandatory:** Every `SKILL.md` must have valid YAML frontmatter containing the `name` and a rich, multi-line `description` trigger block.
2. **Use GitHub Flavored Markdown:** Format with tables, bullet lists, alert blocks (`> [!IMPORTANT]`, `> [!CAUTION]`), and syntax-highlighted code blocks.
3. **Link references correctly:** Link between files using relative markdown links (e.g., `[constitution.md](../constitution/SKILL.md)`). Never use machine-specific or hardcoded absolute file scheme paths (e.g., `file:///var/home/...` or `file:///absolute/path/...`), as these will fail to resolve on other host environments and other developers' machines. Relative paths ensure that references remain portable and resolvable regardless of where the skill is copied, mounted, or checked out.
