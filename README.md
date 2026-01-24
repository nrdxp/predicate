# Predicate

Reusable agent predicates (rulesets) and workflows for agentic coding assistants.

## What's In Here

```
predicate/
├── predicates/              # Foundational rulesets (always-on)
│   ├── global.md            # Base engineering ruleset
│   └── fragments/           # Composable extensions
│       ├── go.md            # Go-specific idioms
│       ├── depmap.md        # DepMap MCP server usage
│       ├── personalization.md # User naming preferences
│       ├── rust.md          # Rust-specific idioms
│       └── typescript.md    # TS/JS-specific idioms
├── workflows/               # Manually-triggered SOPs
│   ├── ai-audit.md          # Audit AI-generated code
│   └── core.md              # C.O.R.E. structured interaction
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

The canonical installation location is `.agent/predicates/` in your project root:

```
your-project/
├── .agent/
│   ├── predicates/
│   │   ├── global.md          # Base ruleset (required)
│   │   └── fragments/         # Active extensions
│   │       ├── go.md
│   │       └── depmap.md
│   └── workflows/
│       ├── ai-audit.md
│       └── core.md
└── AGENTS.md                   # Project context (optional)
```

### Quick Start

```bash
# Clone predicate
git clone https://github.com/nrdxp/predicate.git

# Create .agent directory in your project
mkdir -p /your/project/.agent

# Install predicate and workflows
ln -s /path/to/predicate/predicates /your/project/.agent/predicates
ln -s /path/to/predicate/workflows /your/project/.agent/workflows

# (Optional) Copy AGENTS.md template
cp /path/to/predicate/templates/AGENTS.md /your/project/AGENTS.md
```

### Alternative: Copy Instead of Symlink

```bash
cp -r /path/to/predicate/predicates /your/project/.agent/predicates
cp -r /path/to/predicate/workflows /your/project/.agent/workflows
```

---

## Composing Predicates with Fragments

The base `global.md` predicate is language-agnostic. Add extensions by appending fragments to your predicate file:

```bash
# Create a project-specific predicate with Go, Rust, and MCP guidance
cat predicates/global.md \
    predicates/fragments/go.md \
    predicates/fragments/rust.md \
    predicates/fragments/depmap.md \
    > my-predicate.md
```

### Available Fragments

| Fragment             | Purpose                      |
| :------------------- | :--------------------------- |
| `go.md`              | Go language idioms           |
| `rust.md`            | Rust language idioms         |
| `typescript.md`      | TypeScript/JavaScript idioms |
| `depmap.md`          | DepMap MCP server usage      |
| `personalization.md` | User naming preferences      |

Or manually include the content from relevant fragments at the end of your predicate.

---

## Available Workflows

| Workflow                             | Trigger     | Description                                          |
| :----------------------------------- | :---------- | :--------------------------------------------------- |
| [ai-audit.md](workflows/ai-audit.md) | `/ai-audit` | 4-layer audit framework for AI-generated code        |
| [core.md](workflows/core.md)         | `/core`     | C.O.R.E. protocol for structured agentic interaction |

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

## License

MIT
