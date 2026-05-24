# Project Agent Configuration

## Predicate System

This project **is** [predicate](https://github.com/nrdxp/predicate) — a system for portable, composable agent configuration.

> [!IMPORTANT]
> You **must** review [skills/constitution/SKILL.md](skills/constitution/SKILL.md) and follow its protocol before beginning work.

**Active Skills:**
- commit-hygiene (Commit message formatting and best practices)

This is a documentation-only repository. The language-specific skills (go, rust, etc.) are provided as templates/configurations for other projects, but are not active here. The `skills/integral/SKILL.md` skill guides meta-project reasoning.

> [!NOTE]
> This repository **is** the Predicate source. The `skills/` directory lives at the repo root — not under `.agents/` — because this is the upstream that other projects consume via submodule or symlink. When mounted into a consuming project, these directories appear under `.agents/` as described in `README.md`.

---

## Project Overview

Predicate is a framework for configuring AI coding agents with reusable, portable skills. Under this unified architecture, all rules, workflows, and tools are represented as modular agent skills loaded semantically.

**Purpose:** Replace ad-hoc system prompts with version-controlled, shareable agent configuration.

---

## Repository Structure

| Directory     | Purpose                             |
| :------------ | :---------------------------------- |
| `skills/`     | Encapsulated agent skills (rules, workflows, tools) |
| `templates/`  | Project templates (AGENTS.md)       |
| `docs/`       | Guides, plans, and ADRs             |

---

## Build & Commands

This is a documentation-only repository. No build required.

- Validate markdown: `markdownlint .` (if installed)
- Check links: `python3 skills/doc-audit/scripts/check_docs.py .`

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

- New skills → `skills/` with proper `SKILL.md` frontmatter definition.

---

## Version

Pre-1.0: Breaking changes expected. Design over stability.
