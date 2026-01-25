# Predicate

Reusable agent predicates (rulesets) and workflows for agentic coding assistants.

## What's In Here

```
predicate/
├── predicates/              # Foundational rulesets (always-on)
│   ├── global.md            # Base engineering ruleset
│   └── fragments/           # Composable extensions
│       ├── go.md            # Go-specific idioms
│       ├── rust.md          # Rust-specific idioms
│       ├── typescript.md    # TS/JS-specific idioms
│       ├── depmap.md        # DepMap MCP server usage
│       └── personalization.md # User naming preferences
├── workflows/               # Manually-triggered SOPs
│   ├── ai-audit.md          # Audit AI-generated code
│   ├── core.md              # C.O.R.E. structured interaction
│   └── predicate.md         # Context refresh workflow
└── templates/               # Project templates
    └── AGENTS.md            # AGENTS.md template for projects
```

### Terminology

| Term          | Description                                                            |
| :------------ | :--------------------------------------------------------------------- |
| **Predicate** | A foundational ruleset governing agent behavior. Always active.        |
| **Fragment**  | A composable extension to a predicate (e.g., language-specific rules). |
| **Workflow**  | A task-specific SOP, manually triggered via slash command.             |

---

## Installation

### Option 1: Git Submodule (Recommended)

The cleanest approach—adds predicate as a submodule at `.agent`:

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
│   │   ├── global.md          # Base ruleset (required)
│   │   └── fragments/         # Extensions (mark active in AGENTS.md)
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
