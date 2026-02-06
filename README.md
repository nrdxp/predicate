# Predicate

Reusable agent predicates (rulesets) and workflows for agentic coding assistants.

## What's In Here

```
predicate/
├── predicates/              # Foundational rulesets (always active)
│   ├── engineering.md       # Base engineering ruleset
│   └── fragments/           # Context-specific extensions (opt-in)
│       ├── go.md            # Go-specific idioms
│       ├── rust.md          # Rust-specific idioms
│       ├── typescript.md    # TS/JS-specific idioms
│       ├── depmap.md            # DepMap MCP server usage
│       ├── integral.md          # Holistic problem-solving
│       └── personalization.md # User naming preferences
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

| Term          | Description                                                                            |
| :------------ | :------------------------------------------------------------------------------------- |
| **Predicate** | A foundational ruleset. Any file in `predicates/` is always active — no opt-in needed. |
| **Fragment**  | A context-specific extension in `predicates/fragments/`. Opt-in and task-relevant.     |
| **Workflow**  | A task-specific SOP, manually triggered via slash command.                             |

---

## Philosophy

### Why Predicate?

AI coding assistants need clear, consistent guidance, but system prompts quickly become unwieldy. Predicate separates concerns:

- **Global ruleset** → Engineering principles that apply everywhere
- **Fragments** → Context-specific rules loaded only when relevant
- **Workflows** → Structured procedures triggered on demand

This prevents context overload. A Rust-focused request doesn't need Go idioms; a README update doesn't need language fragments at all. The agent loads only what's relevant to the current task.

### Built on Standards

Predicate integrates with existing conventions rather than inventing new ones:

- **[AGENTS.md](https://agent.md)** — The emerging standard for project-level agent configuration
- **`.agent/` directory** — Common location recognized by agentic tools
- **Workflow triggers** — Slash commands familiar to most agent interfaces

### The Planning Protocols

Predicate includes a layered approach to planning and execution:

```
/sketch  →  /plan  →  /core
```

**SKETCH** (`/sketch`) — Exploratory planning. Diverge before converging. Sketches live in `.sketches/` (gitignored) with their own local git history, preserving ideation archaeology without bloating the main repo.

**PLAN** (`/plan`) — Rigorous planning. Actively seek reasons _not_ to proceed. Produces a committed plan artifact and an ADR before execution begins.

**C.O.R.E.** (`/core`) — Granular execution. Takes each phase from the plan and executes with explicit verification.

> **The best code is no code.** We don't commit to building until we're confident the design is correct. Planning deserves the same rigor we bring to execution.

---

## Installation

### Option 1: Git Submodule (Recommended)

Add predicate as a submodule at `.agent`:

```bash
# Add predicate as submodule
git submodule add https://github.com/nrdxp/predicate.git .agent

# Copy AGENTS.md template to project root
cp .agent/templates/AGENTS.md ./AGENTS.md

# Edit AGENTS.md: fill in project details, build commands, active fragments, etc.
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
ln -s ~/predicate/predicates .agent/predicates
ln -s ~/predicate/workflows .agent/workflows

# Copy AGENTS.md template
cp ~/predicate/templates/AGENTS.md ./AGENTS.md
```

### Option 3: Copy

For projects that can't use submodules or symlinks:

```bash
cp -r /path/to/predicate/predicates .agent/predicates
cp -r /path/to/predicate/workflows .agent/workflows
cp /path/to/predicate/templates/AGENTS.md ./AGENTS.md
```

---

## Project Structure After Installation

```
your-project/
├── .agent/
│   ├── PREDICATE.md              # Predicate system documentation (read first)
│   ├── predicates/
│   │   ├── engineering.md        # Base ruleset (predicate, always active)
│   │   └── fragments/            # Context-specific (mark active in AGENTS.md)
│   └── workflows/
│       └── ...                   # Task-specific SOPs
└── AGENTS.md                     # Project context + active fragments
```

---

## Configuring Active Fragments

Not all fragments apply to every project. In your project's `AGENTS.md`, specify which fragments are active:

```markdown
**Active Fragments:**

- Go idioms
- DepMap MCP usage
```

The agent will only load fragments marked as active and relevant to the current request.

### Available Fragments

| Fragment             | Purpose                      |
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

- **New predicates**: Add to `predicates/`
- **New fragments**: Add to `predicates/fragments/`
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

- Add organization-specific rules or fragments
- Create domain-specific workflows
- Maintain a curated subset of fragments

Fork this repo and use your fork as the submodule source. The composable structure makes it easy to extend without modifying upstream files.

## License

MIT
