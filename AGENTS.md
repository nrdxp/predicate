# Project Agent Configuration

## Predicate System

This project **is** [predicate](https://github.com/nrdxp/predicate) — a system for portable, composable agent configuration.

**Installation Location:** `.agent/predicates/` (symlinked to `predicates/`)

### How Predicates Work

**Predicates** are foundational rulesets. Any file placed directly in the `predicates/` directory is **always active** — the agent must read and adhere to all of them unconditionally.

**Fragments** are context-specific extensions stored in `predicates/fragments/`. These are **opt-in** — only fragments marked as "active" in `AGENTS.md` are loaded, and typically only when relevant to the current task.

```
.agent/
├── predicates/ → ../predicates
│   ├── engineering.md         # Base engineering ruleset (predicate)
│   └── fragments/             # Context-specific extensions (opt-in)
│       ├── go.md              # Go idioms
│       ├── rust.md            # Rust idioms
│       ├── typescript.md      # TS/JS idioms
│       ├── depmap.md          # DepMap MCP usage
│       ├── integral.md        # Integral problem-solving
│       └── personalization.md # User preferences
└── workflows/ → ../workflows
    ├── ai-audit.md            # AI code audit
    ├── core.md                # C.O.R.E. protocol
    └── predicate.md           # Context refresh
```

> [!NOTE]
> The agent must read **all** files directly in `predicates/` (currently just `engineering.md`). Additional predicates can be added — they become automatically active.

**Active Fragments:** `integral.md`

This is a documentation-only repository. The language-specific fragments (go.md, rust.md, etc.) are provided as templates for other projects, but are not active here. The `integral.md` fragment is active to guide meta-project reasoning.

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
