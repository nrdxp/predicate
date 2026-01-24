# Predicate

Reusable agent predicates (rulesets) and workflows for agentic coding assistants.

## What's In Here

```
predicate/
├── predicates/              # Foundational rulesets (always-on)
│   ├── global.md            # Base engineering ruleset
│   └── fragments/           # Composable extensions
│       ├── go.md            # Go-specific idioms
│       ├── mcp.md           # MCP tool guidance
│       ├── personalization.md # User naming preferences
│       ├── rust.md          # Rust-specific idioms
│       └── typescript.md    # TS/JS-specific idioms
└── workflows/               # Manually-triggered SOPs
    ├── ai-audit.md          # Audit AI-generated code
    └── core.md              # C.O.R.E. structured interaction
```

### Terminology

| Term          | Description                                                            |
| :------------ | :--------------------------------------------------------------------- |
| **Predicate** | A foundational ruleset governing agent behavior. Always active.        |
| **Fragment**  | A composable extension to a predicate (e.g., language-specific rules). |
| **Workflow**  | A task-specific SOP, manually triggered via slash command.             |

---

## Installation

### For Antigravity

**Option A: Symlink (recommended)**

```bash
# Clone the repo
git clone https://github.com/nrdxp/predicate.git

# Symlink predicate to your global config
ln -s /path/to/predicate/predicates/global.md ~/.config/antigravity/GEMINI.md

# Symlink workflows to your project
ln -s /path/to/predicate/workflows /your/project/.agent/workflows
```

**Option B: Copy**

```bash
cp /path/to/predicate/predicates/global.md ~/.config/antigravity/GEMINI.md
cp -r /path/to/predicate/workflows /your/project/.agent/workflows
```

### For Other Agents

Most agentic tools support a "system prompt" or "user rules" file. Copy/symlink `predicates/global.md` to the appropriate location for your tool.

---

## Composing Predicates with Fragments

The base `global.md` predicate is language-agnostic. Add extensions by appending fragments to your predicate file:

```bash
# Create a project-specific predicate with Go, Rust, and MCP guidance
cat predicates/global.md \
    predicates/fragments/go.md \
    predicates/fragments/rust.md \
    predicates/fragments/mcp.md \
    > my-predicate.md
```

### Available Fragments

| Fragment             | Purpose                      |
| :------------------- | :--------------------------- |
| `go.md`              | Go language idioms           |
| `rust.md`            | Rust language idioms         |
| `typescript.md`      | TypeScript/JavaScript idioms |
| `mcp.md`             | MCP tool usage guidance      |
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
