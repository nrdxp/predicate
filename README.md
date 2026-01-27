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
│       ├── depmap.md        # DepMap MCP server usage
│       └── personalization.md # User naming preferences
├── workflows/               # Manually-triggered SOPs
│   ├── ai-audit.md          # Audit AI-generated code
│   ├── core.md              # C.O.R.E. structured interaction
│   ├── humanizer.md         # Remove AI writing patterns
│   └── predicate.md         # Context refresh workflow
└── templates/               # Project templates
    └── AGENTS.md            # AGENTS.md template for projects
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

### The C.O.R.E. Protocol

The `/core` workflow is predicate's structured approach to bounded work:

> **C**ontext → **O**bstacles → **R**esolution → **E**xecution

Instead of diving straight into code, C.O.R.E. enforces:

1. **Explicit context gathering** before action
2. **Ambiguity detection** that blocks premature execution
3. **User approval gates** at plan boundaries
4. **Verification assertions** for every change

This keeps work well-specified and prevents the common failure mode of agents confidently executing on misunderstood requirements.

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
│   ├── predicates/
│   │   ├── engineering.md     # Base ruleset (predicate, always active)
│   │   └── fragments/         # Context-specific (mark active in AGENTS.md)
│   └── workflows/
│       ├── ai-audit.md
│       ├── core.md
│       └── predicate.md
└── AGENTS.md                   # Project context + active fragments
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
| `personalization.md` | User naming preferences      |

---

## Available Workflows

| Workflow                               | Trigger      | Description                                          |
| :------------------------------------- | :----------- | :--------------------------------------------------- |
| [ai-audit.md](workflows/ai-audit.md)   | `/ai-audit`  | 4-layer audit framework for AI-generated code        |
| [core.md](workflows/core.md)           | `/core`      | C.O.R.E. protocol for structured agentic interaction |
| [humanizer.md](workflows/humanizer.md) | `/humanizer` | Remove AI writing patterns; make text more natural   |
| [predicate.md](workflows/predicate.md) | `/predicate` | Re-read global rules; combats context drift          |

Workflows can be chained: `/predicate + /core`

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
