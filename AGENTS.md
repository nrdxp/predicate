# Project Agent Configuration

## Predicate System

This project **is** [predicate](https://github.com/nrdxp/predicate) — a system for portable, composable agent configuration.

**Installation Location:** `.agent/predicates/` (symlinked to `predicates/`)

### How Predicates Work

Predicate content lives under `.agent/` at the project root:

```
.agent/
├── predicates/          # Foundational rulesets
│   └── fragments/       # Context-specific extensions
└── workflows/           # Task-specific SOPs
```

**Predicates** are foundational rulesets that are **always active**. Any `.md` file placed directly in `.agent/predicates/` (not in a subdirectory) must be read and followed unconditionally — these are the non-negotiable rules governing agent behavior.

**Fragments** are context-specific extensions stored in `.agent/predicates/fragments/`. These are **opt-in** — only fragments explicitly listed below as "active" are loaded, typically when relevant to the current task.

> [!IMPORTANT]
> The agent must scan `.agent/predicates/` and read **all** `.md` files there before beginning work. Do not rely on any file listing in this document — scan the directory itself.

### Hierarchical Configuration

The [AGENTS.md standard](https://agents.md) supports hierarchical configuration. When working in a subdirectory, the agent should also check for and read any `AGENTS.md` file in that directory for additional context-specific rules. Subdirectory rules supplement (not replace) the root configuration.

**Active Fragments:** None (no fragments are currently marked active)

This is a documentation-only repository. The language-specific fragments (go.md, rust.md, etc.) are provided as templates for other projects, but are not active here. The `integral.md` predicate guides meta-project reasoning.

**Available Workflows:**

- `/ai-audit` — Audit code for AI-generated patterns
- `/core` — C.O.R.E. structured interaction protocol
- `/humanizer` — Remove AI writing patterns from text
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
