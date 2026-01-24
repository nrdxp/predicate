# Project Agent Configuration

## Predicates

This project **is** [predicate](https://github.com/nrdxp/predicate) — a framework for agent configuration.

**Installation Location:** `.agent/predicates/` (symlinked to `predicates/`)

The agent MUST read and adhere to the global engineering ruleset and any active fragments:

```
.agent/
├── predicates/ → ../predicates
│   ├── global.md              # Base engineering ruleset
│   └── fragments/
│       ├── go.md              # Go idioms
│       ├── rust.md            # Rust idioms
│       ├── typescript.md      # TS/JS idioms
│       ├── depmap.md          # DepMap MCP usage
│       └── personalization.md # User preferences
└── workflows/ → ../workflows
    ├── ai-audit.md            # AI code audit
    ├── core.md                # C.O.R.E. protocol
    └── predicate.md           # Context refresh
```

**Active Fragments:** None

This is a documentation-only repository. The language-specific fragments (go.md, rust.md, etc.) are provided as templates for other projects, but are not active here.

**Available Workflows:**

- `/ai-audit` — Audit code for AI-generated patterns
- `/core` — C.O.R.E. structured interaction protocol
- `/predicate` — Re-read global rules; combats context drift

---

## Project Overview

Predicate is a framework for configuring AI coding agents with reusable rulesets (predicates), composable extensions (fragments), and task-specific procedures (workflows).

**Purpose:** Replace ad-hoc system prompts with version-controlled, shareable agent configuration.

---

## Repository Structure

| Directory     | Purpose                       |
| :------------ | :---------------------------- |
| `predicates/` | Base ruleset and fragments    |
| `workflows/`  | Manually-triggered SOPs       |
| `templates/`  | Project templates (AGENTS.md) |

---

## Build & Commands

This is a documentation-only repository. No build required.

- Validate markdown: `markdownlint .` (if installed)
- Check links: `markdown-link-check *.md` (if installed)

---

## Code Style

- **Markdown:** Follow GitHub Flavored Markdown
- **Tables:** Align columns for readability
- **Lists:** Use `-` for unordered lists
- **Headers:** Use `##` sections with `---` separators

---

## Contributing

See [README.md](README.md#contributing) for contribution guidelines.

When adding content:

- New predicates → `predicates/`
- New fragments → `predicates/fragments/`
- New workflows → `workflows/` with proper front-matter

---

## Version

Pre-1.0: Breaking changes expected. Design over stability.
